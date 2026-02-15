# ClaudeOS Proactive Monitor — Claude-authored desktop notifications
#
# Tier 1: Health check timer (every 15 min, pure bash, $0 cost)
# Tier 2: Claude notification service (OnFailure handler, rate-limited)
# Tier 3: Daily morning briefing (9 AM, opt-in)
{
  lib,
  config,
  pkgs,
  ...
}:

let
  # Tier 1: Pure bash health check — no Claude, no cost
  healthCheckScript = pkgs.writeShellScript "claudeos-health-check" ''
    export PATH="${
      pkgs.lib.makeBinPath [
        pkgs.coreutils
        pkgs.systemd
        pkgs.procps
        pkgs.gawk
        pkgs.gnugrep
      ]
    }:/run/current-system/sw/bin:$PATH"
    ${builtins.readFile ./health-check.sh}
  '';

  # Tier 2: Claude-authored notification (or fallback)
  notifyScript = pkgs.writeShellScript "claudeos-notify" ''
    export PATH="${
      pkgs.lib.makeBinPath [
        pkgs.coreutils
        pkgs.systemd
      ]
    }:$PATH"

    CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/claudeos-monitor"
    CONTEXT_FILE="$CACHE_DIR/alert-context.txt"
    COOLDOWN_FILE="$CACHE_DIR/last-claude-call"
    COOLDOWN=1800  # 30 minutes

    # Nothing to report
    [[ ! -s "$CONTEXT_FILE" ]] && exit 0

    context=$(<"$CONTEXT_FILE")

    # --- Rate limit check ---
    use_claude=true
    if [[ -f "$COOLDOWN_FILE" ]]; then
      last=$(stat -c %Y "$COOLDOWN_FILE" 2>/dev/null || echo 0)
      now=$(date +%s)
      (( now - last < COOLDOWN )) && use_claude=false
    fi

    # --- Try Claude-authored notification ---
    if $use_claude; then
      CLAUDE_BIN="$HOME/.local/bin/claude"
      if [[ -x "$CLAUDE_BIN" ]]; then
        prompt="You are ClaudeOS, the AI monitoring this NixOS system. Analyze these system alerts and write a single desktop notification (2-3 sentences max). Be specific and actionable — include the exact command the user should run to fix it if applicable. No markdown, no emoji, plain text only.

    $context"

        notification=$("$CLAUDE_BIN" -p "$prompt" --model sonnet 2>/dev/null) || notification=""

        if [[ -n "$notification" ]]; then
          touch "$COOLDOWN_FILE"
          ${pkgs.libnotify}/bin/notify-send \
            --app-name=ClaudeOS --icon=claude --urgency=critical \
            "ClaudeOS Monitor" "$notification"
          exit 0
        fi
      fi
    fi

    # --- Fallback: truncated raw context ---
    fallback=$(echo "$context" | head -15)
    ${pkgs.libnotify}/bin/notify-send \
      --app-name=ClaudeOS --icon=dialog-warning --urgency=critical \
      "System Alert" "$fallback"
  '';

  # Tier 3: Daily morning briefing
  dailyBriefScript = pkgs.writeShellScript "claudeos-daily-brief" ''
    export PATH="${
      pkgs.lib.makeBinPath [
        pkgs.coreutils
        pkgs.systemd
        pkgs.procps
        pkgs.gawk
      ]
    }:/run/current-system/sw/bin:$PATH"

    # Gather system stats
    stats="System: $(hostname 2>/dev/null || echo unknown)
    Uptime: $(uptime -p 2>/dev/null || echo unknown)
    Load: $(awk '{print $1, $2, $3}' /proc/loadavg 2>/dev/null || echo unknown)
    Memory: $(free -h 2>/dev/null | awk '/^Mem:/ {printf "%s used / %s total", $3, $2}')
    Disk: $(df -h / 2>/dev/null | awk 'NR==2 {printf "%s used / %s total (%s)", $3, $2, $5}')
    Nix generations: $(ls -1d /nix/var/nix/profiles/system-*-link 2>/dev/null | wc -l)
    Failed services: $(systemctl --failed --no-legend --no-pager 2>/dev/null | grep -c . || echo 0) system, $(systemctl --user --failed --no-legend --no-pager 2>/dev/null | grep -c . || echo 0) user"

    CLAUDE_BIN="$HOME/.local/bin/claude"

    if [[ -x "$CLAUDE_BIN" ]]; then
      prompt="You are ClaudeOS, the AI running this NixOS system. Write a friendly 2-3 sentence morning briefing based on these system stats. Mention anything noteworthy or concerning. Be concise, warm, and helpful. No markdown, no emoji, plain text only.

    $stats"

      brief=$("$CLAUDE_BIN" -p "$prompt" --model sonnet 2>/dev/null) || brief=""

      if [[ -n "$brief" ]]; then
        ${pkgs.libnotify}/bin/notify-send \
          --app-name=ClaudeOS --icon=claude \
          "Good Morning" "$brief"
        exit 0
      fi
    fi

    # Fallback: raw stats
    ${pkgs.libnotify}/bin/notify-send \
      --app-name=ClaudeOS --icon=dialog-information \
      "Morning Brief" "$stats"
  '';
in
{
  options.claude-os.monitor = {
    enable = lib.mkEnableOption "ClaudeOS proactive health monitoring with Claude-authored notifications";
    dailyBrief = lib.mkEnableOption "daily morning system briefing from ClaudeOS";
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
          after = [ "graphical-session.target" ];
          wants = [ "graphical-session.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = toString notifyScript;
          };
        };
      }

      # ========================================================================
      # Tier 3: Daily morning briefing
      # ========================================================================
      (lib.mkIf config.claude-os.monitor.dailyBrief {
        systemd.user.services.claudeos-daily-brief = {
          description = "ClaudeOS morning system briefing";
          after = [ "graphical-session.target" ];
          wants = [ "graphical-session.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = toString dailyBriefScript;
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

    ]
  );
}
