# ClaudeOS Proactive Monitor — Claude-authored desktop notifications
#
# Tier 1: Health check timer (every 15 min, pure bash, $0 cost)
# Tier 2: Claude notification service (OnFailure handler, rate-limited)
# Tier 3: Daily morning briefing (9 AM, opt-in)
# Tier 4: Journald diary — nightly haiku triage of error-level journal entries
#         against a persistent ledger (docs/known-issues.md in the repo);
#         actionable findings surface in the morning brief
{
  lib,
  config,
  pkgs,
  ...
}:

let
  claudeLib = import ../../../lib/claude-script.nix { inherit pkgs lib; };

  # Tier 1: Pure bash health check — no Claude, no cost
  healthCheckScript = claudeLib.mkClaudeScript {
    name = "claudeos-health-check";
    text = builtins.readFile ./health-check.sh;
  };

  # Tier 2: Claude-authored notification with action buttons
  notifyScript = claudeLib.mkClaudeScript {
    name = "claudeos-notify";
    runtimeInputs = [ pkgs.ghostty ];
    text = ''
      CONTEXT_FILE="$MONITOR_CACHE_DIR/alert-context.txt"
      COOLDOWN_FILE="$MONITOR_CACHE_DIR/last-claude-call"
      COOLDOWN=1800  # 30 minutes

      # Nothing to report
      [[ ! -s "$CONTEXT_FILE" ]] && exit 0

      context=$(<"$CONTEXT_FILE")

      # --- Rate limit check ---
      use_claude=true
      claudeos_cooldown_ok "$COOLDOWN_FILE" "$COOLDOWN" || use_claude=false

      # --- Try Claude-authored notification ---
      if $use_claude; then
        prompt="You are ClaudeOS, the AI monitoring this NixOS system. Analyze these system alerts and respond with ONLY the notification body text (2-3 sentences max). Be specific and actionable — include the exact command the user should run to fix it if applicable. No markdown, no emoji, no titles, no tool use — just output plain text and nothing else.

      $context"

        # haiku: a 2-3 sentence notification on a 15-min timer path is the
        # cost doctrine's textbook high-frequency lane
        notification=$(claude_text haiku "$prompt")

        if [[ -n "$notification" ]]; then
          touch "$COOLDOWN_FILE"
          action=$(claudeos_notify --icon=claude --urgency=critical \
            -A "fix=Open in Claude" -A "dismiss=Dismiss" \
            "ClaudeOS Monitor" "$notification")

          if [[ "$action" == "fix" ]]; then
            claude_interactive "ClaudeOS health monitor detected issues on this system. Here is the alert context:

      $context

      --- Claude notification summary ---
      $notification

      Diagnose and fix these issues. Check journalctl, systemctl, and other system tools for more information as needed." "$CLAUDEOS_DIAG_TOOLS"
          fi
          exit 0
        fi
      fi

      # --- Fallback: truncated raw context ---
      fallback=$(echo "$context" | head -15)
      action=$(claudeos_notify --icon=dialog-warning --urgency=critical \
        -A "fix=Open in Claude" -A "dismiss=Dismiss" \
        "System Alert" "$fallback")

      if [[ "$action" == "fix" ]]; then
        claude_interactive "ClaudeOS health monitor detected issues on this system. Here is the raw alert context:

      $context

      Diagnose and fix these issues. Check journalctl, systemctl, and other system tools for more information as needed." "$CLAUDEOS_DIAG_TOOLS"
      fi
    '';
  };

  # Tier 3: Daily morning briefing (writes to cache file for terminal MOTD + notification)
  dailyBriefScript = claudeLib.mkClaudeScript {
    name = "claudeos-daily-brief";
    runtimeInputs = [ pkgs.ghostty ];
    text = ''
      BRIEF_FILE="$DAILY_BRIEF_FILE"
      STATS_FILE="$MONITOR_CACHE_DIR/daily-stats.txt"
      mkdir -p "$MONITOR_CACHE_DIR"

      now=$(date +%s)

      # --- System health (persistent/actionable signals only) ---
      failed_units=$(claudeos_failed_units)
      nix_store=$(df -h /nix/store 2>/dev/null | awk 'NR==2 {printf "%s used / %s", $3, $2}')
      generations=$(ls -1d /nix/var/nix/profiles/system-*-link 2>/dev/null | wc -l)

      # --- Config status ---
      # Last rebuild: when the current system profile was activated
      rebuild_epoch=$(stat -c %Y /nix/var/nix/profiles/system 2>/dev/null || echo 0)
      rebuild_days=$(( (now - rebuild_epoch) / 86400 ))
      rebuild_date=$(date -d "@$rebuild_epoch" "+%Y-%m-%d %H:%M" 2>/dev/null || echo unknown)

      # Last successful auto-update (breadcrumb; falls back to flake.lock's
      # git date) — mtime lied here: a checkout refreshes it without any
      # inputs actually moving
      update_age=$(claudeos_update_age_days)

      stats="Host: $(hostname 2>/dev/null || echo unknown)
      Uptime: $(uptime -p 2>/dev/null || echo unknown)
      Failed services: ''${failed_units:-none}
      Root disk: $(claudeos_disk_pct)% used
      Nix store: $nix_store
      Nix generations: $generations
      Last rebuild: $rebuild_date ($rebuild_days days ago)
      Last successful flake update: $update_age days ago
      Config repo: $(claudeos_repo_summary)"

      # Overnight journal-diary findings (Tier 4) feed the brief
      if [[ -s "$DIARY_ACTIONABLE_FILE" ]]; then
        stats="$stats
      Journal diary (overnight triage): $(cat "$DIARY_ACTIONABLE_FILE")"
      fi

      # Save stats for the "Details" action
      echo "$stats" > "$STATS_FILE"

      prompt="You are ClaudeOS, the AI that manages this NixOS system. Write a concise daily briefing (2-4 sentences) for the terminal MOTD. Focus on what needs attention or action — failed services, stale config, uncommitted work, disk pressure. If everything looks healthy, say so briefly. No markdown, no emoji, plain text only.

      $stats"

      # haiku: 2-4 sentences from pre-collected stats, every single day —
      # high-frequency lane per the cost doctrine (the morning DESK keeps
      # sonnet: it synthesizes a full dashboard)
      brief=$(claude_text haiku "$prompt")

      if [[ -n "$brief" ]]; then
        echo "$brief" > "$BRIEF_FILE"

        # Send notification with action button
        action=$(claudeos_notify --icon=claude \
          -A "details=Details" -A "dismiss=Dismiss" \
          "Good Morning" "$brief")

        if [[ "$action" == "details" ]]; then
          claude_interactive "Good morning. Here are the current system stats for this NixOS machine:

      $stats

      Review the system state and let me know if anything needs attention. Check journalctl, systemctl, and other system tools for more details on any issues." "$CLAUDEOS_DIAG_TOOLS"
        fi
        exit 0
      fi

      # Fallback: raw stats if Claude unavailable
      echo "$stats" > "$BRIEF_FILE"
      claudeos_notify --icon=dialog-information \
        "Good Morning" "Daily briefing ready — check your terminal."
    '';
  };

  # Tier 4: Journald diary — error triage with persistent memory.
  # Unlike a grep cron job, the agent maintains its own ledger across runs
  # (docs/known-issues.md, committed via the normal rebuild auto-commit flow),
  # so known-benign noise is silenced and only NEW signatures surface.
  journalDiaryScript = claudeLib.mkClaudeScript {
    name = "claudeos-journal-diary";
    text = ''
      mkdir -p "$MONITOR_CACHE_DIR"

      # grep -v: the session-bus dbus-broker's "Ignoring duplicate name" spam
      # can't be filtered at journald ingest (LogFilterPatterns is enforced
      # for system units only) — drop it here so it can't crowd the triage
      errors=$(journalctl -p err..alert --since "-24 hours" --no-pager --output=cat 2>/dev/null \
        | grep -v "Ignoring duplicate name" \
        | sort | uniq -c | sort -rn | head -50)
      if [[ -z "$errors" ]]; then
        rm -f "$DIARY_ACTIONABLE_FILE"
        exit 0
      fi
      [[ -x "$CLAUDE_BIN" ]] || exit 0
      cd "$CLAUDEOS_DIR" || exit 1

      prompt="You are the ClaudeOS journal diary. Below are deduplicated error-level journal lines from the last 24h (count, then message). Your ledger of known issues is docs/known-issues.md in this repo.

      1. Read the ledger. For each error signature below, decide: already in the ledger (skip), new-benign (append to the ledger under Benign with today's date and one-line verdict), or new-actionable (append under Actionable with date, verdict, and the next step).
      2. Edit ONLY docs/known-issues.md. Do not run git commands — your edits ride the next rebuild auto-commit.
      3. Final output: ONLY the new ACTIONABLE findings, one line each (max 3 lines, plain text). If there are none, output exactly: OK

      $errors"

      text=$(claude_headless haiku "$prompt" --allowedTools 'Read,Edit,Grep,Glob,Bash(journalctl*)')

      if [[ -n "$text" && "$text" != "OK" ]]; then
        echo "$text" > "$DIARY_ACTIONABLE_FILE"
      else
        rm -f "$DIARY_ACTIONABLE_FILE"
      fi
    '';
  };
in
{
  options.claude-os.monitor = {
    enable = lib.mkEnableOption "ClaudeOS proactive health monitoring with Claude-authored notifications";
    dailyBrief = lib.mkEnableOption "daily morning system briefing from ClaudeOS";
    journalDiary = lib.mkEnableOption "nightly Claude triage of journal errors against the known-issues ledger";
  };

  config = lib.mkIf config.claude-os.monitor.enable (
    lib.mkMerge [

      # ========================================================================
      # Tier 1 + 2: Health check timer + Claude notification handler
      # ========================================================================
      {
        systemd.user.services.claudeos-health-check = {
          description = "ClaudeOS system health check";
          unitConfig.OnFailure = "claudeos-notify.service";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = toString healthCheckScript;
          };
        };

        systemd.user.timers.claudeos-health-check = {
          description = "Run ClaudeOS health check every 15 minutes";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "5min";
            OnUnitActiveSec = "15min";
          };
        };

        systemd.user.services.claudeos-notify = {
          description = "ClaudeOS Claude-authored notification handler";
          # Ordering only — `wants` here would ACTIVATE graphical-session.target
          # in whatever user manager starts this unit (the jasper.nix bug that
          # broke GDM greeters on 2026-07-05). Never pull that target in.
          after = [ "graphical-session.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = toString notifyScript;
            # notify-send -A blocks waiting for user to click an action button.
            # Allow up to 30 min before systemd kills us (matches cooldown period).
            TimeoutStartSec = "30min";
          };
        };
      }

      # ========================================================================
      # Tier 3: Daily morning briefing
      # ========================================================================
      (lib.mkIf config.claude-os.monitor.dailyBrief {
        systemd.user.services.claudeos-daily-brief = {
          description = "ClaudeOS morning system briefing";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = toString dailyBriefScript;
            # notify-send -A blocks waiting for user to click an action button.
            TimeoutStartSec = "30min";
          };
        };

        systemd.user.timers.claudeos-daily-brief = {
          description = "ClaudeOS daily morning briefing at 9 AM";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "*-*-* 09:00:00";
            Persistent = true;
          };
        };
      })

      # ========================================================================
      # Tier 4: Journald diary (nightly, before the morning brief)
      # ========================================================================
      (lib.mkIf config.claude-os.monitor.journalDiary {
        systemd.user.services.claudeos-journal-diary = {
          description = "ClaudeOS nightly journal error triage";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = toString journalDiaryScript;
            TimeoutStartSec = "15min";
            SyslogIdentifier = "claudeos-diary";
          };
        };

        systemd.user.timers.claudeos-journal-diary = {
          description = "ClaudeOS journal diary at 4 AM";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "*-*-* 04:00:00";
            Persistent = true;
          };
        };
      })

    ]
  );
}
