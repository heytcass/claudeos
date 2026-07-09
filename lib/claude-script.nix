# lib/claude-script.nix — shared scaffolding for the ClaudeOS agent scripts.
#
# Every Claude-invoking shell script (auto-update, self-heal, monitor tiers,
# morning desk, desktop commands) gets the same preamble: a deterministic
# PATH, the shared path constants, and helper functions for the recurring
# moves — desktop notifications, headless agent calls with session
# bookkeeping (the `approve` fish function resumes the recorded session),
# and "open Claude in a quick terminal" handoffs.
#
# Usage: claudeLib = import ../../lib/claude-script.nix { inherit pkgs lib; };
#        claudeLib.mkClaudeScript { name = "..."; runtimeInputs = [ ... ]; text = ''...''; }
{ pkgs, lib }:

let
  # Tools every agent script gets for free — all tiny and already in the
  # system closure. Task-specific extras go in runtimeInputs.
  baseInputs = with pkgs; [
    coreutils
    gnugrep
    gnused
    gawk
    jq
    git
    systemd
    libnotify
    hostname
    procps
  ];

  preamble = runtimeInputs: ''
    export PATH="${
      lib.makeBinPath (runtimeInputs ++ baseInputs)
    }:$HOME/.local/bin:/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:$PATH"

    CLAUDE_BIN="$HOME/.local/bin/claude"
    CLAUDEOS_DIR="$HOME/.config/claudeos"
    STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/claudeos"
    # Monitor cache contract: the journal diary WRITES diary-actionable.txt,
    # the morning desk and daily brief READ it; the daily brief WRITES
    # daily-brief.txt, fish's first-shell MOTD reads it (fish can't source
    # this preamble — home/shell/fish.nix restates that one path).
    MONITOR_CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/claudeos-monitor"
    DIARY_ACTIONABLE_FILE="$MONITOR_CACHE_DIR/diary-actionable.txt"
    DAILY_BRIEF_FILE="$MONITOR_CACHE_DIR/daily-brief.txt"
    # Diagnostic tool set for interactive "open in Claude" handoffs
    CLAUDEOS_DIAG_TOOLS='Bash,Read,Grep,Glob,mcp__system-health__*'

    claudeos_notify() { notify-send --app-name=ClaudeOS "$@"; }

    # Seconds a blocking `-A` notification waits for a click before giving up.
    # Must stay well under the calling unit's TimeoutStartSec: notify-send -A
    # blocks until someone clicks, and when nobody does, systemd SIGTERMs the
    # unit into `failed` — which the health check then reads as a system fault
    # and alerts on, every 15 minutes, forever.
    CLAUDEOS_NOTIFY_WAIT=900

    # claudeos_notify_action ARGS... — the blocking `-A` form of the above.
    # Prints the chosen action id, or nothing once the wait expires. Never
    # fails: a notification nobody answered is not an error.
    claudeos_notify_action() {
      timeout "$CLAUDEOS_NOTIFY_WAIT" notify-send --app-name=ClaudeOS "$@" || true
    }

    # Headless GitHub credential: with lingering, agent scripts can run with
    # no graphical session, where gh's keyring-backed token is locked. Export
    # the sops automation token as GH_TOKEN when it exists (gh and its git
    # credential helper both honor it); inside a session the keyring still
    # works without it. Safe no-op while the secret is a placeholder/absent.
    claudeos_export_gh_token() {
      local tok
      if [[ -r /run/secrets/github_automation_token ]]; then
        tok=$(</run/secrets/github_automation_token)
        [[ -n "$tok" && "$tok" != PLACEHOLDER* ]] && export GH_TOKEN="$tok"
      fi
      return 0
    }

    # Days since the last SUCCESSFUL auto-update (breadcrumb written by
    # claudeos-auto-update), falling back to flake.lock's last commit date.
    # Prints an integer, or "unknown".
    claudeos_update_age_days() {
      local epoch=0
      if [[ -f "$STATE_DIR/last-update" ]]; then
        epoch=$(date -d "$(<"$STATE_DIR/last-update")" +%s 2>/dev/null || echo 0)
      fi
      if [[ "$epoch" -eq 0 && -d "$CLAUDEOS_DIR/.git" ]]; then
        epoch=$(git -C "$CLAUDEOS_DIR" log -1 --format=%ct -- flake.lock 2>/dev/null || echo 0)
      fi
      if [[ "$epoch" -gt 0 ]]; then
        echo $(( ($(date +%s) - epoch) / 86400 ))
      else
        echo "unknown"
      fi
    }

    # claude_text MODEL PROMPT [extra claude args...] — guarded one-shot
    # plain-text call, the most common shape. Prints the result; prints
    # nothing (rc 0) when the CLI is missing or the call fails, so callers
    # can just test for empty output.
    claude_text() {
      local model="$1" prompt="$2"
      shift 2
      [[ -x "$CLAUDE_BIN" ]] || return 0
      "$CLAUDE_BIN" -p "$prompt" --model "$model" "$@" 2>/dev/null || true
    }

    # claudeos_cooldown_ok FILE SECONDS — rate-limit gate: succeeds when at
    # least SECONDS have passed since FILE was last touched (or it doesn't
    # exist). Check-only — the caller stamps FILE when it actually acts.
    claudeos_cooldown_ok() {
      local last
      last=$(stat -c %Y "$1" 2>/dev/null || echo 0)
      (( $(date +%s) - last >= $2 ))
    }

    # claude_headless MODEL PROMPT [extra claude args...] — headless agent
    # call. Records the session id so the fish `approve` function can resume
    # it, then prints the result text (empty on failure).
    claude_headless() {
      local model="$1" prompt="$2" result session
      shift 2
      result=$("$CLAUDE_BIN" -p "$prompt" --model "$model" --output-format json "$@" 2>/dev/null) || result=""
      session=$(echo "$result" | jq -r '.session_id // empty' 2>/dev/null)
      if [[ -n "$session" ]]; then
        mkdir -p "$STATE_DIR"
        echo "$session" > "$STATE_DIR/last-agent-session"
      fi
      echo "$result" | jq -r '.result // empty' 2>/dev/null
    }

    # claude_interactive PROMPT ALLOWED_TOOLS [extra claude args...] — Claude
    # in a quick-terminal window, held open until Enter so output can be read.
    # Needs ghostty in runtimeInputs (or on the inherited PATH).
    claude_interactive() {
      local prompt="$1" tools="$2" extra="" arg
      shift 2
      for arg in "$@"; do extra+=" $(printf '%q' "$arg")"; done
      ghostty --class=claude-quick -e bash -c "claude -p $(printf '%q' "$prompt") --allowedTools $(printf '%q' "$tools")$extra
    echo
    echo 'Press Enter to close...'
    read"
    }

    # Shared system-state collectors (daily brief, morning desk)
    claudeos_failed_units() {
      (systemctl --failed --no-legend --plain; systemctl --user --failed --no-legend --plain) 2>/dev/null \
        | awk '{print $1}' | paste -sd', ' -
    }

    claudeos_disk_pct() { df / 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}'; }

    claudeos_repo_summary() {
      local branch dirty unpushed out
      [[ -d "$CLAUDEOS_DIR/.git" ]] || { echo "not a git repo"; return; }
      branch=$(git -C "$CLAUDEOS_DIR" branch --show-current 2>/dev/null || echo unknown)
      dirty=$(git -C "$CLAUDEOS_DIR" status --porcelain 2>/dev/null | wc -l)
      unpushed=$(git -C "$CLAUDEOS_DIR" log @{u}..HEAD --oneline 2>/dev/null | wc -l)
      out="branch $branch"
      [[ $dirty -gt 0 ]] && out="$out, $dirty uncommitted changes"
      [[ $unpushed -gt 0 ]] && out="$out, $unpushed unpushed commits"
      echo "$out"
    }
  '';

  mkBody =
    {
      runtimeInputs ? [ ],
      text,
      ...
    }:
    preamble runtimeInputs + "\n" + text;
in
{
  # writeShellScript with the agent preamble (systemd services etc.)
  mkClaudeScript = args: pkgs.writeShellScript args.name (mkBody args);

  # Same, as a bin package on PATH (user-facing commands)
  mkClaudeScriptBin = args: pkgs.writeShellScriptBin args.name (mkBody args);
}
