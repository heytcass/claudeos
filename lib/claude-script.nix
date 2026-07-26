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
  # Card infrastructure (Phase 4). The action registry (lib/card-actions.nix) is
  # the closed set of commands a card `run` action may name — claudeos_card below
  # rejects any `run` name outside it. The schema file is the repo-tracked card
  # contract check-jsonschema enforces. Both are referenced in the preamble.
  cardActions = import ./card-actions.nix;
  cardNames = lib.concatStringsSep " " (lib.attrNames cardActions);
  cardSchema = ../home/quickshell/cards/card.schema.json;

  # Context infrastructure (Phase 3). The manifest schema (repo-tracked) is the
  # contract both the claudeos-context CLI and the claudeos_context_emit lane
  # helper validate against — a malformed manifest is rejected before it can
  # half-restore a workspace.
  contextSchema = ../modules/apps/contexts/context.schema.json;

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
    # curl is base, not per-lane: claudeos_wait_for_network below is the first
    # thing a boot-time lane runs, so it cannot depend on the lane having
    # remembered to list curl in runtimeInputs.
    curl
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

    # claudeos_wait_for_network [BUDGET_SECONDS] — block until the network can
    # actually resolve and reach the internet. Returns 0 on the first
    # successful probe, 1 when the budget (default 120s) expires.
    #
    # Every lane that can run at boot must call this before its first network
    # collector. User units cannot order after the system network-online.target,
    # and NetworkManager-wait-online is disabled repo-wide for boot speed
    # (modules/common/networking.nix) — so a timer's Persistent=true catch-up
    # fires ~12s after boot, long before there is any DNS.
    #
    # Observed on transporter 2026-07-26: boot 09:38:02, every user timer fired
    # 09:38:14, the ethernet link did not come up until 09:40:19 and DNS landed
    # 09:40:27. In that 2m17s hole the morning desk reported "Calendar isn't
    # connected (fetch failed)" against a perfectly valid gcalcli token (and
    # told the user to re-run `gcalcli init`, which was the wrong remedy), and
    # jasper burned its entire 3-minute TimeoutStartSec and was SIGTERMed.
    #
    # Probe hits a DNS name, not a bare IP: a resolver that is not up yet is
    # exactly the failure being waited out, so name resolution has to be part
    # of the test.
    # BUDGET is wall-clock, enforced against a deadline rather than by summing
    # the sleeps: each iteration also burns up to `curl -m 5`, so a naive
    # counter overshoots by ~2x. That gap is not cosmetic — jasper's budget sits
    # inside a 3-minute TimeoutStartSec, and a 2x overshoot would put it right
    # back at the SIGTERM this helper exists to prevent.
    claudeos_wait_for_network() {
      local budget="''${1:-120}" deadline
      deadline=$(( $(date +%s) + budget ))
      while (( $(date +%s) < deadline )); do
        curl -fsIm 5 https://www.google.com >/dev/null 2>&1 && return 0
        sleep 5
      done
      return 1
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

    # ---- Generated surfaces (cards) — Phase 4 -------------------------------
    # Cards are ephemeral, schema-validated DATA surfaces rendered
    # deterministically by CardSurface.qml. They live in $XDG_RUNTIME_DIR
    # (tmpfs) so they die on reboot for free, and the bar only ever renders a
    # card that PASSED validation — an invalid card degrades to a plain
    # notification carrying the reason (the lane hears about its own malformed
    # output; the bar never renders junk).
    CLAUDEOS_CARDS_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/claudeos-cards.d"
    CLAUDEOS_CARD_SCHEMA="${cardSchema}"
    # Space-padded list of valid `run` action names (lib/card-actions.nix).
    _CLAUDEOS_CARD_RUNS=" ${cardNames} "

    # claudeos_card FILE [ID] — validate a card against the schema + the closed
    # action registry, then atomically install it as <ID>.json (default ID: the
    # lane name, so re-emitting a card REPLACES rather than stacks). Cards.qml
    # polls this dir for the card files directly (like Presence polls agent.d);
    # there is no index file. On ANY failure the card is not installed; a
    # notification carries the reason.
    claudeos_card() {
      local src="$1" id="''${2:-$(_claudeos_lane)}" err bad safe dir="$CLAUDEOS_CARDS_DIR"
      [[ -f "$src" ]] || { claudeos_notify "Card error" "no such card file: $src"; return 1; }
      if ! command -v check-jsonschema >/dev/null 2>&1; then
        claudeos_notify "Card error" "check-jsonschema not on PATH — add pkgs.check-jsonschema to this lane's runtimeInputs"
        return 1
      fi
      # 1. structural validation against the repo-tracked schema
      if ! err=$(check-jsonschema --schemafile "$CLAUDEOS_CARD_SCHEMA" "$src" 2>&1); then
        claudeos_notify "Card rejected" "schema: $(printf '%s' "$err" | tr '\n' ' ' | tail -c 260)"
        return 1
      fi
      # 2. every `run` action name must be in the closed registry
      bad=$(jq -r --arg reg "$_CLAUDEOS_CARD_RUNS" '
        [ .sections[]? | select(.type=="actions") | .actions[]? | select(.type=="run") | .name ]
        | map(select(. as $n | ($reg | index(" " + $n + " ")) == null)) | .[0] // empty' "$src" 2>/dev/null)
      if [[ -n "$bad" ]]; then
        claudeos_notify "Card rejected" "action run '$bad' is not in the card action registry"
        return 1
      fi
      # 3. atomic install under the stable id, then refresh the watched index
      safe=$(printf '%s' "$id" | tr -c 'a-zA-Z0-9._-' '-' | tr -s '-' | sed 's/^-//; s/-$//')
      [[ -z "$safe" ]] && safe=card
      mkdir -p "$dir"
      jq -c '.' "$src" > "$dir/$safe.json.tmp" 2>/dev/null && mv "$dir/$safe.json.tmp" "$dir/$safe.json"
    }

    # claudeos_lane_card ID TITLE ICON URGENCY TEXT [URL [LABEL]] — the one-call
    # lane-end card: TEXT as a text section, an optional link chip, a Dismiss
    # action. This is the standard "the lane finished — here's the durable
    # record" surface: notifications vanish (or block waiting for a click), a
    # card stays until dismissed. Re-emitting under the same stable ID REPLACES
    # the lane's previous card rather than stacking. Same degradation contract
    # as claudeos_card: an invalid card is never installed, a notification
    # carries the reason. Empty ICON/URGENCY/URL are simply omitted.
    claudeos_lane_card() {
      local id="$1" title="$2" icon="$3" urgency="$4" body="$5" url="''${6:-}" label="''${7:-Open}" tmp rc=0
      tmp=$(mktemp)
      # Truncation mirrors the schema's limits (title 120, text 2000, url 2000,
      # label 100) so a long changelog degrades to a clipped card, not a reject.
      jq -n --arg title "''${title:0:120}" --arg icon "$icon" --arg urgency "$urgency" \
            --arg body "''${body:0:1900}" --arg url "''${url:0:2000}" --arg label "''${label:0:100}" '
        {title: $title, sections: [{type: "text", text: $body}]}
        | if $icon != "" then .icon = $icon else . end
        | if $urgency != "" then .urgency = $urgency else . end
        | if $url != "" then .sections += [{type: "links", links: [{label: $label, url: $url}]}] else . end
        | .sections += [{type: "actions", actions: [{type: "dismiss", label: "Dismiss"}]}]
      ' > "$tmp" || { rm -f "$tmp"; return 1; }
      claudeos_card "$tmp" "$id" || rc=1
      rm -f "$tmp"
      return $rc
    }

    # ---- Task contexts — Phase 3 --------------------------------------------
    # A context is a named, git-tracked text manifest of a workspace's TOOLS and
    # PLACES (schema: modules/apps/contexts/context.schema.json). The dir is its
    # OWN standalone git repo — history and diffability without polluting the
    # system repo or declaring ring-2 state in Nix. The claudeos-context CLI
    # (save/restore/list/rm) and the claudeos_context_emit lane helper below both
    # install through claudeos_context_install, so validation + commit are one
    # implementation.
    CLAUDEOS_CONTEXTS_DIR="$STATE_DIR/contexts"
    CLAUDEOS_CONTEXT_SCHEMA="${contextSchema}"

    # Filesystem slug for a context name: lowercase, non-alnum → single hyphen,
    # trimmed. The slug is both the manifest filename and the Hyprland workspace
    # name, so restore/focus/idempotency all key off one stable string.
    _claudeos_context_slug() {
      printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-' | tr -s '-' | sed 's/^-*//; s/-*$//'
    }

    # Commit the contexts dir (auto-init on first use). Local identity only —
    # these commits are machine-local and never pushed.
    _claudeos_context_commit() {
      local msg="$1" dir="$CLAUDEOS_CONTEXTS_DIR"
      if [[ ! -d "$dir/.git" ]]; then
        git -C "$dir" init -q 2>/dev/null || return 0
        git -C "$dir" config user.name "ClaudeOS" 2>/dev/null || true
        git -C "$dir" config user.email "claudeos@localhost" 2>/dev/null || true
      fi
      git -C "$dir" add -A 2>/dev/null || true
      git -C "$dir" diff --cached --quiet 2>/dev/null || git -C "$dir" commit -q -m "$msg" 2>/dev/null || true
    }

    # claudeos_context_install FILE NAME — validate a manifest against the schema,
    # then atomically install it as <slug>.json and commit. Preserves an existing
    # context's `created` timestamp and forces `name`/`updated`, so a re-save
    # never drifts the name or loses provenance. Prints the slug on success;
    # returns non-zero WITHOUT writing on any validation failure.
    claudeos_context_install() {
      local src="$1" name="$2" slug err created merged dir="$CLAUDEOS_CONTEXTS_DIR"
      [[ -f "$src" ]] || { echo "no such manifest: $src" >&2; return 1; }
      slug=$(_claudeos_context_slug "$name")
      [[ -z "$slug" ]] && { echo "empty context name" >&2; return 1; }
      if ! command -v check-jsonschema >/dev/null 2>&1; then
        echo "check-jsonschema not on PATH — add pkgs.check-jsonschema to runtimeInputs" >&2
        return 1
      fi
      if ! err=$(check-jsonschema --schemafile "$CLAUDEOS_CONTEXT_SCHEMA" "$src" 2>&1); then
        echo "manifest rejected: $(printf '%s' "$err" | tr '\n' ' ' | tail -c 300)" >&2
        return 1
      fi
      mkdir -p "$dir"
      created=$(jq -r '.created // empty' "$dir/$slug.json" 2>/dev/null)
      [[ -z "$created" ]] && created=$(date +%s)
      merged=$(jq -c --arg name "$name" --argjson created "$created" --argjson updated "$(date +%s)" \
        '.name=$name | .created=$created | .updated=$updated' "$src") || return 1
      printf '%s\n' "$merged" > "$dir/$slug.json.tmp" && mv "$dir/$slug.json.tmp" "$dir/$slug.json"
      _claudeos_context_commit "save $slug"
      printf '%s\n' "$slug"
    }

    # claudeos_context_emit FILE [NAME] — the lane-facing writer (agent
    # preparation: a lane leaves a context pointing at what it gathered). NAME
    # defaults to the manifest's own `.name`. On any failure the context is not
    # installed and a notification carries the reason — the lane hears about its
    # own malformed output; the bar never reads a broken manifest.
    claudeos_context_emit() {
      local src="$1" name="''${2:-}" out
      [[ -f "$src" ]] || { claudeos_notify "Context error" "no such manifest: $src"; return 1; }
      [[ -z "$name" ]] && name=$(jq -r '.name // empty' "$src" 2>/dev/null)
      [[ -z "$name" ]] && { claudeos_notify "Context rejected" "manifest has no name"; return 1; }
      if ! out=$(claudeos_context_install "$src" "$name" 2>&1); then
        claudeos_notify "Context rejected" "$(printf '%s' "$out" | tail -c 200)"
        return 1
      fi
      return 0
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
