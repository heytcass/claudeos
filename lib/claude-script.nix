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

    # Tag lane notifications with x-claudeos-lane so the shell's router (Phase
    # 1b, home/quickshell/Notifications.qml) can route by lane if a rule wants
    # to; harmless metadata otherwise. Only genuine lanes (CLAUDEOS_LANE set)
    # are tagged. _claudeos_lane is defined below in the preamble — resolved at
    # call time, so definition order doesn't matter.
    claudeos_notify() {
      if [[ -n "''${CLAUDEOS_LANE:-}" ]]; then
        notify-send --app-name=ClaudeOS -h "string:x-claudeos-lane:$(_claudeos_lane)" "$@"
      else
        notify-send --app-name=ClaudeOS "$@"
      fi
    }

    # Agent presence: the bar's island shows what the machine is doing to
    # itself (Agent.qml reads the newest fresh file in this dir and displays
    # its first line — the "agent face"). One file per process, so concurrent
    # agents coexist; the EXIT trap clears it however the script ends, and the
    # bar ignores files older than 60 min as a stuck-marker backstop.
    CLAUDEOS_AGENT_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/claudeos-agent.d"

    # JSON-encode one string as a bare JSON value (used for the presence
    # sidecar and ledger below). jq is always in baseInputs.
    _claudeos_json() { jq -Rn --arg s "$1" '$s'; }

    # The lane's short name for presence surfaces. A lane may set CLAUDEOS_LANE
    # ("wish", "self-heal", …); unset, we fall back to the script's basename
    # with the leading /nix/store hash stripped (writeShellScript names the file
    # <hash>-<name>), so a lane that forgets still reads sensibly.
    _claudeos_lane() {
      if [[ -n "''${CLAUDEOS_LANE:-}" ]]; then
        printf '%s' "$CLAUDEOS_LANE"
      else
        printf '%s' "''${0##*/}" | sed -E 's/^[a-z0-9]{32}-//'
      fi
    }

    claudeos_agent_begin() {
      mkdir -p "$CLAUDEOS_AGENT_DIR"
      printf '%s\n' "$1" > "$CLAUDEOS_AGENT_DIR/$$"
      # Structured sidecar for the Presence surface (home/quickshell/Presence.qml):
      # lane name + the same phrase (line 1) + start epoch. This is purely
      # additive — the plain <pid> file above stays byte-identical, so Agent.qml
      # keeps working unmodified as the always-present fallback.
      printf '{"lane":%s,"phrase":%s,"started":%s}\n' \
        "$(_claudeos_json "$(_claudeos_lane)")" \
        "$(_claudeos_json "$1")" \
        "$(date +%s)" > "$CLAUDEOS_AGENT_DIR/$$.json"
      # Call-scoped pulses (and Claude Code hooks) inherit the script's
      # phrase — without this a claude_* call would overwrite "healing …"
      # with a newer generic "working" marker for its duration.
      export CLAUDEOS_AGENT_ACTIVITY="$1"
      trap claudeos_agent_end EXIT
    }
    claudeos_agent_end() { rm -f "$CLAUDEOS_AGENT_DIR/$$" "$CLAUDEOS_AGENT_DIR/$$.json"; }

    # claudeos_agent_done RESULT [URL] — record one line of finished lane work
    # in the presence ledger (PresencePanel's "recently finished" section).
    # Append-then-tail-rewrite keeps the last 20 lines; the atomic mv means a
    # concurrent reader never sees a half-truncated file. Call this just before
    # the script exits (while the live marker is still up); the EXIT trap clears
    # the live marker immediately after. URL is optional — an empty url renders
    # as a non-clickable row.
    claudeos_agent_done() {
      local result="$1" url="''${2:-}" ledger="$MONITOR_CACHE_DIR/presence-done.jsonl"
      mkdir -p "$MONITOR_CACHE_DIR"
      printf '{"lane":%s,"result":%s,"url":%s,"ts":%s}\n' \
        "$(_claudeos_json "$(_claudeos_lane)")" \
        "$(_claudeos_json "$result")" \
        "$(_claudeos_json "$url")" \
        "$(date +%s)" >> "$ledger"
      tail -n 20 "$ledger" > "$ledger.tmp" 2>/dev/null && mv "$ledger.tmp" "$ledger"
    }

    # Call-scoped pulse, written by the claude_* helpers below: the island
    # breathes for exactly the duration of each CLI call, with no per-script
    # wiring to forget (that's how the pulse went unseen — every automation
    # inherited claudeos_agent_begin and only morning-desk called it).
    # Scripts set CLAUDEOS_AGENT_ACTIVITY for a curated phrase ("musing");
    # unset, the island says "working". Named call-$BASHPID, not $$: unique
    # inside command-substitution subshells, and it can never clobber a
    # script-scoped claudeos_agent_begin marker. No trap — the explicit end
    # suffices, and a SIGKILLed call ages out via the bar's 60-min backstop.
    _claudeos_pulse_begin() {
      mkdir -p "$CLAUDEOS_AGENT_DIR"
      printf '%s\n' "''${CLAUDEOS_AGENT_ACTIVITY:-working}" > "$CLAUDEOS_AGENT_DIR/call-$BASHPID"
    }
    _claudeos_pulse_end() { rm -f "$CLAUDEOS_AGENT_DIR/call-$BASHPID"; }

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
      if [[ -n "''${CLAUDEOS_LANE:-}" ]]; then
        timeout "$CLAUDEOS_NOTIFY_WAIT" notify-send --app-name=ClaudeOS -h "string:x-claudeos-lane:$(_claudeos_lane)" "$@" || true
      else
        timeout "$CLAUDEOS_NOTIFY_WAIT" notify-send --app-name=ClaudeOS "$@" || true
      fi
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
      local model="$1" prompt="$2" out rc=0
      shift 2
      [[ -x "$CLAUDE_BIN" ]] || return 0
      # Capture before printing: on a non-zero exit the CLI's stdout is error
      # text ("You've hit your monthly spend limit"), not an answer — piping
      # it through breaks every caller that tests for empty output.
      _claudeos_pulse_begin
      out=$("$CLAUDE_BIN" -p "$prompt" --model "$model" "$@" 2>/dev/null) || rc=$?
      _claudeos_pulse_end
      [[ "$rc" -eq 0 ]] || return 0
      printf '%s\n' "$out"
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
      _claudeos_pulse_begin
      result=$("$CLAUDE_BIN" -p "$prompt" --model "$model" --output-format json "$@" 2>/dev/null) || result=""
      _claudeos_pulse_end
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

    # Shared personal-world collectors (morning desk, jasper lane) — one
    # implementation of the wttr.in fetch and the gcalcli guard; consumers jq
    # their own shape out of the raw JSON.

    # Raw wttr.in j1 JSON, cached 15 min so co-scheduled lanes share a fetch.
    # Prints nothing when the fetch fails and no cache exists; a stale cache
    # beats an empty answer. Needs curl in runtimeInputs.
    claudeos_wttr_json() {
      local cache="$MONITOR_CACHE_DIR/wttr-j1.json" out
      mkdir -p "$MONITOR_CACHE_DIR"
      if [[ -s "$cache" ]] && (( $(date +%s) - $(stat -c %Y "$cache") < 900 )); then
        cat "$cache"
        return 0
      fi
      out=$(timeout 15 curl -fsSL "wttr.in/?format=j1" 2>/dev/null) || out=""
      if [[ -n "$out" ]]; then
        printf '%s' "$out" > "$cache"
        printf '%s' "$out"
      elif [[ -s "$cache" ]]; then
        cat "$cache"
      fi
    }

    # claudeos_gcal_agenda START END [extra gcalcli agenda args...] — guarded
    # calendar fetch. Prints the agenda, "not connected" before the one-time
    # `gcalcli init` (OAuth client in sops: jasper_google_client_id/secret),
    # or "fetch failed". Needs gcalcli in runtimeInputs.
    claudeos_gcal_agenda() {
      local start="$1" end="$2"
      shift 2
      if ! command -v gcalcli >/dev/null || [[ ! -d "$HOME/.local/share/gcalcli" && ! -f "$HOME/.gcalcli_oauth" ]]; then
        echo "not connected"
        return 0
      fi
      timeout 60 gcalcli --nocolor agenda "$@" "$start" "$end" 2>/dev/null || echo "fetch failed"
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
