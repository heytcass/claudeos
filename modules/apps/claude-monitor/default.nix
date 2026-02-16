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

  # Tier 3: Daily morning briefing (writes to cache file for terminal MOTD)
  dailyBriefScript = pkgs.writeShellScript "claudeos-daily-brief" ''
    export PATH="${
      pkgs.lib.makeBinPath [
        pkgs.coreutils
        pkgs.systemd
        pkgs.procps
        pkgs.gawk
        pkgs.git
      ]
    }:/run/current-system/sw/bin:$PATH"

    CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/claudeos-monitor"
    BRIEF_FILE="$CACHE_DIR/daily-brief.txt"
    CLAUDEOS_DIR="$HOME/.config/claudeos"
    mkdir -p "$CACHE_DIR"

    now=$(date +%s)

    # --- System health (persistent/actionable signals only) ---
    host=$(hostname 2>/dev/null || echo unknown)
    up=$(uptime -p 2>/dev/null || echo unknown)

    # Failed services — list names, not just counts
    failed_sys=$(systemctl --failed --no-legend --no-pager 2>/dev/null | awk '{print $2}' | paste -sd", " || true)
    failed_usr=$(systemctl --user --failed --no-legend --no-pager 2>/dev/null | awk '{print $2}' | paste -sd", " || true)
    [[ -z "$failed_sys" ]] && failed_sys="none"
    [[ -z "$failed_usr" ]] && failed_usr="none"

    # Disk — only flag percentage, noteworthy if high
    disk_pct=$(df / 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
    nix_store=$(df -h /nix/store 2>/dev/null | awk 'NR==2 {printf "%s used / %s", $3, $2}')

    # Nix generations
    generations=$(ls -1d /nix/var/nix/profiles/system-*-link 2>/dev/null | wc -l)

    # --- Config status ---
    # Last rebuild: when the current system profile was activated
    rebuild_epoch=$(stat -c %Y /nix/var/nix/profiles/system 2>/dev/null || echo 0)
    rebuild_days=$(( (now - rebuild_epoch) / 86400 ))
    rebuild_date=$(date -d "@$rebuild_epoch" "+%Y-%m-%d %H:%M" 2>/dev/null || echo unknown)

    # Flake lock age: when was nixpkgs last updated
    if [[ -f "$CLAUDEOS_DIR/flake.lock" ]]; then
      lock_epoch=$(stat -c %Y "$CLAUDEOS_DIR/flake.lock" 2>/dev/null || echo 0)
      lock_days=$(( (now - lock_epoch) / 86400 ))
    else
      lock_days="unknown"
    fi

    # Git status of claudeos repo
    if [[ -d "$CLAUDEOS_DIR/.git" ]]; then
      dirty=$(git -C "$CLAUDEOS_DIR" status --porcelain 2>/dev/null | wc -l)
      unpushed=$(git -C "$CLAUDEOS_DIR" log @{u}..HEAD --oneline 2>/dev/null | wc -l)
      git_info=""
      [[ $dirty -gt 0 ]] && git_info="$dirty uncommitted changes"
      [[ $unpushed -gt 0 ]] && git_info="''${git_info:+$git_info, }$unpushed unpushed commits"
      [[ -z "$git_info" ]] && git_info="clean, up to date"
      branch=$(git -C "$CLAUDEOS_DIR" branch --show-current 2>/dev/null || echo unknown)
    else
      git_info="not a git repo"
      branch="n/a"
    fi

    stats="Host: $host
    Uptime: $up
    Failed services (system): $failed_sys
    Failed services (user): $failed_usr
    Root disk: ''${disk_pct}% used
    Nix store: $nix_store
    Nix generations: $generations
    Last rebuild: $rebuild_date ($rebuild_days days ago)
    Flake lock age: $lock_days days
    Config branch: $branch
    Config repo: $git_info"

    CLAUDE_BIN="$HOME/.local/bin/claude"

    if [[ -x "$CLAUDE_BIN" ]]; then
      prompt="You are ClaudeOS, the AI that manages this NixOS system. Write a concise daily briefing (2-4 sentences) for the terminal MOTD. Focus on what needs attention or action — failed services, stale config, uncommitted work, disk pressure. If everything looks healthy, say so briefly. No markdown, no emoji, plain text only.

    $stats"

      brief=$("$CLAUDE_BIN" -p "$prompt" --model sonnet 2>/dev/null) || brief=""

      if [[ -n "$brief" ]]; then
        echo "$brief" > "$BRIEF_FILE"
        exit 0
      fi
    fi

    # Fallback: raw stats if Claude unavailable
    echo "$stats" > "$BRIEF_FILE"
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
