# modules/apps/morning-desk.nix — the day starts already prepared.
#
# Overnight (05:30), an agent reads the morning: calendar (gcalcli, if
# connected), weather, the journal diary's overnight findings, repo and
# system state — and writes ~/Desk/today/index.html: a self-contained,
# Stylix-themed dashboard ordered by what deserves attention first
# (Jasper doctrine: ONE most important thing on top, never a feed).
# At first login of the day it opens automatically in Chrome app mode.
#
# DE-agnostic by design: the artifact is a file; the opener is a URL.
# Calendar bootstrap (one-time, interactive): run `gcalcli init` with the
# Google OAuth client from sops (jasper_google_client_id/secret).
#
# Cost: one sonnet call per day, riding the Claude subscription.
{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.claude-os.morningDesk;

  claudeLib = import ../../lib/claude-script.nix { inherit pkgs lib; };

  # Stylix palette for the no-Claude fallback page (the themed page proper is
  # built by Claude from palette.json at runtime)
  colors = config.lib.stylix.colors.withHashtag;

  buildScript = claudeLib.mkClaudeScript {
    name = "claudeos-morning-desk";
    runtimeInputs = [
      pkgs.curl
      pkgs.gcalcli
    ];
    text = ''
      DESK_DIR="$HOME/Desk/today"
      ARCHIVE_DIR="$HOME/Desk/archive"
      mkdir -p "$DESK_DIR" "$ARCHIVE_DIR"

      # Archive a previous day's dashboard before overwriting
      if [[ -f "$DESK_DIR/index.html" ]]; then
        prev_day=$(date -r "$DESK_DIR/index.html" +%F 2>/dev/null)
        [[ "$prev_day" != "$(date +%F)" && -n "$prev_day" ]] \
          && cp "$DESK_DIR/index.html" "$ARCHIVE_DIR/$prev_day.html" 2>/dev/null
      fi

      # ---- Collectors (each degrades gracefully) ----
      today=$(date "+%A, %B %-d, %Y")

      weather=$(timeout 15 curl -fsSL "wttr.in/?format=j1" 2>/dev/null \
        | jq -c '{now: .current_condition[0] | {tempF: .temp_F, feelsF: .FeelsLikeF, desc: .weatherDesc[0].value}, today: .weather[0] | {maxF: .maxtempF, minF: .mintempF, hourly: [.hourly[] | {time, tempF, chanceofrain, desc: .weatherDesc[0].value}]}}' 2>/dev/null)
      [[ -z "$weather" ]] && weather="unavailable"

      calendar="not connected — run: gcalcli init (OAuth client in sops as jasper_google_client_id/secret)"
      if command -v gcalcli >/dev/null && [[ -d "$HOME/.local/share/gcalcli" || -f "$HOME/.gcalcli_oauth" ]]; then
        calendar=$(timeout 60 gcalcli --nocolor agenda "$(date +%F)" "$(date -d tomorrow +%F)" 2>/dev/null || echo "fetch failed")
      fi

      diary=""
      [[ -s "$DIARY_ACTIONABLE_FILE" ]] && diary=$(cat "$DIARY_ACTIONABLE_FILE")

      failed_units=$(claudeos_failed_units)
      disk_pct=$(claudeos_disk_pct)
      repo=$(claudeos_repo_summary)
      update_age=$(claudeos_update_age_days)

      palette=$(cat "$HOME/.config/stylix/palette.json" 2>/dev/null || echo "{}")

      snapshot="DATE: $today on $(hostname)
      WEATHER (json or unavailable): $weather
      CALENDAR (today + tomorrow): $calendar
      OVERNIGHT JOURNAL TRIAGE: ''${diary:-nothing actionable}
      SYSTEM: failed units: ''${failed_units:-none}; root disk ''${disk_pct:-?}% used; last successful flake update ''${update_age:-unknown} days ago
      CONFIG REPO: ''${repo:-unknown}"

      # ---- The brain: one page, attention-first ----
      html=""
      if [[ -x "$CLAUDE_BIN" ]]; then
        prompt="You are ClaudeOS. Build today's morning dashboard as ONE complete self-contained HTML5 file (inline CSS, no external resources, no frameworks; minimal inline JS only if it earns its place).

      Design doctrine:
      - Information hierarchy is the product: the single most important thing about today goes on top, large and unmissable (a conflict, a deadline, the first meeting, a deliberate 'clear morning — protect it'). Never a feed.
      - Then: today's timeline (calendar items with times), weather woven in only where it affects plans.
      - Then: smaller — anything actionable from the overnight journal triage.
      - Footer, smallest: system state (only if something is wrong) and config repo state.
      - Don't restate raw data; synthesize. Don't invent events. If the calendar isn't connected, show a small setup hint card, not an error.
      - Theme it with this base16 palette (JSON: key → hex without #). Dark background (base00/base01), readable text (base05), one accent used sparingly (base0D): $palette
      - Typography: system-ui stack, generous whitespace, readable at a glance from arm's length. Title the page 'Today'.

      Output ONLY the raw HTML document, starting with <!DOCTYPE html>. No markdown fences, no commentary.

      CONTEXT SNAPSHOT:
      $snapshot"

        html=$(claude_headless sonnet "$prompt" | sed -e 's/^```html$//' -e 's/^```$//')
      fi

      if [[ "$html" == *"<html"* ]]; then
        echo "$html" > "$DESK_DIR/index.html"
      else
        # Fallback: plain but honest
        {
          echo "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>Today</title></head>"
          echo "<body style=\"background:${colors.base00};color:${colors.base05};font-family:system-ui;padding:2rem\">"
          echo "<h1>$today</h1><pre style=\"white-space:pre-wrap\">$snapshot</pre>"
          echo "<p style=\"color:${colors.base03}\">Claude was unavailable — raw snapshot shown.</p></body></html>"
        } > "$DESK_DIR/index.html"
      fi
    '';
  };

  showScript = pkgs.writeShellScript "claudeos-morning-desk-show" ''
    export PATH="${
      pkgs.lib.makeBinPath [
        pkgs.coreutils
        pkgs.google-chrome
      ]
    }:$PATH"
    STAMP_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/claudeos-desk"
    mkdir -p "$STAMP_DIR"
    STAMP="$STAMP_DIR/shown-$(date +%F)"
    [[ -e "$STAMP" ]] && exit 0
    DESK="$HOME/Desk/today/index.html"
    # Wait (up to 10 min) for TODAY'S dashboard: at first login the
    # Persistent=true catch-up build may still be running — opening
    # yesterday's file now would show a stale page and stamp the day done.
    for _ in $(seq 120); do
      [[ -f "$DESK" && "$(date -r "$DESK" +%F)" == "$(date +%F)" ]] && break
      sleep 5
    done
    [[ -f "$DESK" ]] || exit 0
    [[ "$(date -r "$DESK" +%F)" == "$(date +%F)" ]] || exit 0
    sleep 8 # let the session settle before claiming the screen
    touch "$STAMP"
    exec google-chrome-stable --app="file://$DESK"
  '';
in
{
  options.claude-os.morningDesk = {
    enable = lib.mkEnableOption "overnight-built HTML morning dashboard, auto-opened at first login";

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 05:30:00";
      description = "When to build the dashboard (systemd calendar expression).";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.claudeos-morning-desk = {
      description = "ClaudeOS morning desk dashboard build";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = toString buildScript;
        TimeoutStartSec = "15min";
        SyslogIdentifier = "morning-desk";
      };
    };

    systemd.user.timers.claudeos-morning-desk = {
      description = "Build the morning desk dashboard";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
      };
    };

    systemd.user.services.claudeos-morning-desk-show = {
      description = "Open today's dashboard at first login";
      wantedBy = [ "graphical-session.target" ];
      # Order after the build when both jobs are queued together (login-time
      # Persistent catch-up); the in-script wait covers the async case.
      after = [
        "graphical-session.target"
        "claudeos-morning-desk.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = toString showScript;
      };
    };
  };
}
