# modules/apps/jasper.nix — Jasper, the personal-companion lane.
#
# Jasper WAS a standalone Rust daemon (github:heytcass/jasper). It is now a
# ClaudeOS *lane*, not a process — see docs/PHILOSOPHY.md "On Jasper
# specifically": take the thinking, not the daemon. The daemon's genuinely
# good ideas are ported here and nothing else:
#   - significance-gating (only call the model when the world changed)
#   - a single glanceable insight (never a feed)
#   - family-calendar OWNERSHIP awareness ("Alex has soccer," never "you
#     have soccer") — the reason a plain calendar widget isn't enough.
# Departure nudges are qualitative here (the model reasons from event LOCATIONS
# via `gcalcli --details location`). Precise Google-Routes travel-time math (the
# old daemon's travel.rs, using jasper_google_routes_api_key + jasper_home_address)
# is a deliberate future enhancement, not wired yet — the prompt never claims a
# drive duration it wasn't given.
#
# Shape (like morning-desk.nix): a cheap timer polls dumb collectors (gcalcli,
# wttr.in), a bash significance gate decides whether anything changed, and only
# then does ONE `claude -p` call (the single brain — no dedicated
# ANTHROPIC_API_KEY, it rides the Claude subscription) synthesise the insight.
# The result lands in the monitor-cache file contract as jasper-insight.txt;
# the Quickshell bar (home/quickshell/Jasper.qml) is its face.
#
# Calendar bootstrap (one-time, interactive): run `gcalcli init` with the
# Google OAuth client from sops (jasper_google_client_id / jasper_google_client_secret).
# Until then the lane runs weather-only and says the schedule is unknown —
# it never invents events.
{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.claude-os.jasper;
  claudeLib = import ../../lib/claude-script.nix { inherit pkgs lib; };

  laneScript = claudeLib.mkClaudeScript {
    name = "claudeos-jasper";
    runtimeInputs = [
      pkgs.curl
      pkgs.gcalcli
    ];
    text = ''
      CLAUDEOS_LANE=jasper
      INSIGHT_FILE="$MONITOR_CACHE_DIR/jasper-insight.txt"
      META_FILE="$MONITOR_CACHE_DIR/jasper-insight.json"
      HASH_FILE="$MONITOR_CACHE_DIR/jasper-context.hash"
      mkdir -p "$MONITOR_CACHE_DIR"

      user_title=${lib.escapeShellArg cfg.userTitle}
      persona=${lib.escapeShellArg cfg.persona}

      now_human=$(date "+%A, %B %-d at %-I:%M %p")
      now_hour=$(date +%-H)

      # Time-of-day phase + whether we're inside a heartbeat window. Jasper's
      # daemon woke at morning/midday/evening regardless of change; we honour
      # that so the bar isn't stale on a quiet day.
      phase="the day"; heartbeat=0
      if   (( now_hour >= 6  && now_hour < 11 )); then phase="morning";   (( now_hour == 7  )) && heartbeat=1
      elif (( now_hour >= 11 && now_hour < 14 )); then phase="midday";    (( now_hour == 12 )) && heartbeat=1
      elif (( now_hour >= 17 && now_hour < 21 )); then phase="evening";   (( now_hour == 18 )) && heartbeat=1
      fi

      # A boot-time catch-up run (Persistent=true) starts before the network
      # does; without this the collectors below all miss and jasper spends its
      # whole 3-minute TimeoutStartSec failing. Budget is kept well inside that
      # timeout so a genuinely offline machine exits cleanly instead of being
      # SIGTERMed into `failed` and alerting the health check.
      claudeos_wait_for_network 90 || true

      # ---- Collectors (shared with morning-desk: lib/claude-script.nix) ----
      # Weather: keep only the STABLE fields in the gate (condition + the day's
      # hi/lo), not the live temperature, so a 1°F tick doesn't force a call.
      weather_json=$(claudeos_wttr_json \
        | jq -c '{desc: .current_condition[0].weatherDesc[0].value, tempF: .current_condition[0].temp_F, maxF: .weather[0].maxtempF, minF: .weather[0].mintempF, rain: [.weather[0].hourly[] | select((.chanceofrain|tonumber) > 40) | .time]}' 2>/dev/null)
      [[ -z "$weather_json" ]] && weather_json='"unavailable"'
      weather_stable=$(printf '%s' "$weather_json" | jq -c '{desc, maxF, minF, rain}' 2>/dev/null || echo "$weather_json")

      # Calendar: today + tomorrow, labelled by calendar name so the model can
      # attribute ownership. "not connected" before the one-time gcalcli init.
      calendar=$(claudeos_gcal_agenda "$(date +%F)" "$(date -d '2 days' +%F)" --details calendar --details location)
      [[ -z "$calendar" ]] && calendar="nothing on the calendar"

      # ---- Significance gate ----
      # Hash the STABLE context. Call the model only when it changed OR a
      # heartbeat window is due and the last insight is stale ( > cooldown ).
      context_hash=$(printf '%s' "$(date +%F)|$phase|$calendar|$weather_stable" | sha256sum | cut -d' ' -f1)
      prev_hash=$(cat "$HASH_FILE" 2>/dev/null || echo "")

      should_run=0
      if [[ "$context_hash" != "$prev_hash" ]]; then
        should_run=1              # the world changed
      elif (( heartbeat == 1 )) && claudeos_cooldown_ok "$INSIGHT_FILE" ${toString cfg.heartbeatCooldownSec}; then
        should_run=1              # scheduled check-in, and the bar has gone stale
      fi

      if (( should_run == 0 )); then
        exit 0                    # nothing worth a token; leave the current insight up
      fi

      # Previous insight, so the model can avoid repeating itself.
      last_insight=$(cat "$INSIGHT_FILE" 2>/dev/null || echo "none yet")

      # Optional personal context file (Jasper's context.md) — relationships,
      # routines, who's who — appended verbatim if present.
      personal_context=""
      if [[ -n ${lib.escapeShellArg cfg.personalContextFile} && -r ${lib.escapeShellArg cfg.personalContextFile} ]]; then
        personal_context=$(cat ${lib.escapeShellArg cfg.personalContextFile})
      fi

      # ---- The brain: one call, one sentence. Ported from the daemon's prompt. ----
      prompt="You are $persona, a warm, perceptive personal companion. You provide a
      SINGLE glanceable insight for $user_title's status bar — like Android's At a
      Glance widget, but smarter.

      Current time: $now_human ($phase).

      Your job: surface the ONE most useful thing $user_title needs to know right now.
      An insight is NOT just an event — it can be a conflict, a logistics problem, a
      timing crunch, a departure reminder, or a creeping deadline. Think like a
      thoughtful family coordinator who can see everyone's calendars.

      Prioritise (roughly): (1) logistics conflicts — two people needed in different
      places at once, or $user_title double-booked; (2) tight back-to-back timing,
      especially with travel; (3) something needing action in the next 1-2 hours;
      (4) departure reminders when an event is across town; (5) deadlines that are
      easy to forget; (6) weather ONLY when it actually changes plans.

      Rules — these are hard:
      - Do not simply restate a calendar entry; add value beyond what a calendar shows.
      - NEVER invent or assume events that are not in the context below. If the
        schedule is empty, say the day looks clear — do not fabricate.
      - Calendars are labelled. Events on a calendar named after another person are
        THAT person's, shown for awareness only. Frame them as 'Alex has a call at
        3pm', never 'you have a call at 3pm'. Only $user_title's own/primary calendar
        is theirs.
      - If the calendar is 'not connected', do not mention specific events; give a
        light weather- or time-of-day-based nudge instead.
      - Address the user only as '$user_title'. Never 'Sir', 'Ma'am', or any other title.
      - Do not repeat the previous insight below.

      Output: ONE concise, warm sentence, starting with a single emoji that fits the
      mood (vary it; don't reuse the last one), then a space, then the sentence — the
      bar shows only the emoji, the sentence appears on click, so the emoji must
      carry the mood alone. No preamble, no quotes, no markdown.

      Previous insight (do NOT repeat): $last_insight

      CONTEXT
      Weather (json or 'unavailable'): $weather_json
      Calendar (today + tomorrow, labelled by calendar): $calendar''${personal_context:+

      Personal context about $user_title (use to interpret events): $personal_context}"

      export CLAUDEOS_AGENT_ACTIVITY="musing" # island phrase while the call runs
      insight=$(claude_text sonnet "$prompt" | tr -d '\r' | sed '/^[[:space:]]*$/d' | head -1)

      # Only overwrite on a real answer — a failed/empty call must never blank the
      # bar or advance the hash (so the next run retries instead of going quiet).
      if [[ -n "$insight" ]]; then
        printf '%s\n' "$insight" > "$INSIGHT_FILE"
        printf '{"insight":%s,"phase":%s,"ts":%s}\n' \
          "$(jq -Rn --arg s "$insight" '$s')" \
          "$(jq -Rn --arg s "$phase" '$s')" \
          "$(date +%s)" > "$META_FILE"
        printf '%s' "$context_hash" > "$HASH_FILE"
        # A fresh musing is finished lane work — the insight itself is the
        # artifact (it also rides the bar's emoji + calendar popup). No url:
        # the ledger row is a non-clickable memory of what Jasper noticed.
        claudeos_agent_done "$insight"
      fi
    '';
  };
in
{
  options.claude-os.jasper = {
    enable = lib.mkEnableOption "Jasper personal-companion lane (glanceable insight for the bar)";

    userTitle = lib.mkOption {
      type = lib.types.str;
      default = "Tom";
      description = "How Jasper addresses you. Used verbatim in the prompt.";
    };

    persona = lib.mkOption {
      type = lib.types.str;
      default = "Jasper";
      description = "The companion's name/persona voice.";
    };

    personalContextFile = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "/home/tom/.config/jasper-companion/context.md";
      description = ''
        Optional path to a free-form Markdown file describing relationships,
        routines, and who's who. Appended verbatim to the prompt when readable.
        Empty disables it.
      '';
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 06..21:00/30:00";
      description = ''
        How often to poll the collectors (systemd calendar expression). The poll
        is cheap shell; the model is called only when the significance gate
        fires, so a frequent poll does not mean frequent tokens. Default: every
        30 min during waking hours.
      '';
    };

    heartbeatCooldownSec = lib.mkOption {
      type = lib.types.int;
      default = 14400; # 4h
      description = ''
        Minimum seconds between forced heartbeat insights (morning/midday/
        evening) when the context has not otherwise changed.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.claudeos-jasper = {
      description = "Jasper personal-companion insight";
      # A user timer service — it must NEVER touch graphical-session.target.
      # (The retired daemon's greeter-killing boot loop came from exactly that;
      # a plain oneshot on timers.target cannot reproduce it.)
      serviceConfig = {
        Type = "oneshot";
        ExecStart = toString laneScript;
        TimeoutStartSec = "3min";
        SyslogIdentifier = "jasper";
      };
    };

    systemd.user.timers.claudeos-jasper = {
      description = "Poll context for the Jasper companion insight";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
      };
    };
  };
}
