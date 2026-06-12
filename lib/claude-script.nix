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
    # Diagnostic tool set for interactive "open in Claude" handoffs
    CLAUDEOS_DIAG_TOOLS='Bash,Read,Grep,Glob,mcp__system-health*'

    claudeos_notify() { notify-send --app-name=ClaudeOS "$@"; }

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
