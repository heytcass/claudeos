# AI-Native HMI: execution work orders

*2026-07-18. Companion to `2026-07-17-ai-native-hmi-implementation.md` (the
plan) and `2026-07-17-ai-native-hmi-vision.md` (the why). This document
exists for one reason: the cost doctrine — **design with the best model
available; run on the standard ones.** The plan was written with judgment;
these work orders front-load that judgment so a standard-model session can
execute a phase by transcription plus verification, not by re-deriving
design. If you are the executing session: follow the order literally, run
every probe and acceptance step, and when reality disagrees with the spec,
STOP and report — do not improvise past a failed assumption.*

---

## Protocol for every work order

Do these in order at the start of any session executing a work order:

1. Read `.claude/rules/quickshell-qml.md` (auto-loads when touching
   `home/quickshell/`) and the "Quickshell API gotchas" section of
   `docs/plans/2026-07-10-hyprland-handoff.md`. Do not write against any
   `Quickshell.*` API from memory — if this order doesn't pin the API and
   the gotchas doc doesn't cover it, probe it (see each order's PROBE
   steps).
2. Never write a Nix option or package name from memory — query the `nixos`
   MCP server.
3. Validation loop for anything under `home/quickshell/` or the Hyprland
   config: `quickshell_check` (system-health MCP) must pass before any
   rebuild; `hypr_config_check` for new hyprland.conf fields;
   `nix build .#nixosConfigurations.$(hostname).config.system.build.toplevel --dry-run`
   for **both** hosts; `nix fmt` before commit. The commit hook denies
   commits with staged `.nix` files unless the flake evaluates — that is
   expected, not an obstacle.
4. One work order = one PR on a `claude/*` branch. Do not combine orders.
   Do not touch `flake.nix`, `flake.lock`, `.sops.yaml`, `secrets/`,
   `.github/`, `.claude/` in any of these orders — none requires it.
5. Colors/fonts/metrics: `Theme.*` tokens only. A raw `#rrggbb` anywhere in
   QML is a defect.
6. STOP-AND-REPORT triggers (global): a probe returns a shape this doc
   doesn't describe; `quickshell_check` fails twice on the same error; an
   acceptance step fails after one fix attempt; you find yourself designing
   something this doc doesn't specify. Report what you found; a
   design-capable session picks it up.

---

## WO-0 — notification dedup (ships alone, 10 minutes)

**File:** `home/quickshell/Notifications.qml` only.

Today `onNotification` sets `notif.tracked = actionable` (actionable →
corner toast) and then unconditionally emits `root.posted(...)` (island
peek). Result: actionable notifications render twice.

**Change:** make the `posted` emission conditional — replace

```qml
root.posted(notif.summary, notif.body, notif.appName, notif.urgency);
```

with

```qml
if (!actionable)
    root.posted(notif.summary, notif.body, notif.appName, notif.urgency);
```

Also update the comment above it (it currently documents the peek-everything
behavior). Nothing else changes; history retention stays unconditional.

**Acceptance** (run on the live machine):
- `notify-send "hello"` → island peeks, **no** corner toast.
- `notify-send -u critical "on fire"` → corner toast, island does **not**
  peek.
- `notify-send -A ok=OK "choose"` → corner toast with a button, no peek.
- All three appear once each in the calendar-dropdown history.

---

## WO-1a — presence: contracts, singleton, panel

**Files:** `lib/claude-script.nix`, new `home/quickshell/Presence.qml`, new
`home/quickshell/PresencePanel.qml`, edits to `home/quickshell/Island.qml`
and `home/quickshell/ProposalsWidget.qml`, one-line adoption in each lane
(see step 4).

### Step 1 — writer helpers (`lib/claude-script.nix`)

In `claudeos_agent_begin`, after the existing
`printf '%s\n' "$1" > "$CLAUDEOS_AGENT_DIR/$$"`, add a sidecar write. The
lane name is the script's `name` (available as `$CLAUDEOS_LANE` — export it
in the preamble from the mkClaudeScript `name` argument, which requires
threading one variable through `preamble`/`mkClaudeScript`; if that plumbing
is unclear, fall back to `${0##*/}`):

```bash
jq -n --arg lane "${CLAUDEOS_LANE:-${0##*/}}" --arg phrase "$1" \
  --argjson ts "$(date +%s)" '{lane:$lane, phrase:$phrase, started:$ts}' \
  > "$CLAUDEOS_AGENT_DIR/$$.json"
```

**Invariant: the plain `$$` file's contents do not change by one byte** —
Agent.qml keeps reading it. The EXIT trap that removes `$$` must also remove
`$$.json`.

New function `claudeos_agent_done`:

```bash
# claudeos_agent_done "one-line result" [url] — append to the finished-work
# ledger (Presence panel "recently finished"). Cap at 20 entries.
claudeos_agent_done() {
  local ledger="$MONITOR_CACHE_DIR/presence-done.jsonl"
  mkdir -p "$MONITOR_CACHE_DIR"
  jq -cn --arg lane "${CLAUDEOS_LANE:-${0##*/}}" --arg what "$1" \
    --arg url "${2:-}" --argjson ts "$(date +%s)" \
    '{lane:$lane, what:$what, url:$url, ts:$ts}' >> "$ledger"
  tail -n 20 "$ledger" > "$ledger.tmp" && mv "$ledger.tmp" "$ledger"
}
```

### Step 2 — `Presence.qml` (singleton)

Copy the Process+Timer+SplitParser idiom from `Agent.qml` verbatim (same
2.5s cadence, same `@` sentinel). One probe prints one line of JSON built
with `jq -s`:

```
@{"live":[...all fresh $$.json contents...],"recent":[...tail of ledger...]}
```

Shell (one `sh -c`, mirroring Agent.qml's structure):

```bash
live=$(find "$XDG_RUNTIME_DIR/claudeos-agent.d" -maxdepth 1 -name '*.json' -mmin -60 \
  -exec cat {} + 2>/dev/null | jq -sc '.' 2>/dev/null || echo '[]')
recent=$(tail -n 8 "${XDG_CACHE_HOME:-$HOME/.cache}/claudeos-monitor/presence-done.jsonl" 2>/dev/null \
  | jq -sc 'reverse' 2>/dev/null || echo '[]')
echo "@{\"live\":$live,\"recent\":$recent}"
```

In QML, `JSON.parse` inside a try/catch; on parse failure keep previous
state (never blank on garbage — same philosophy as the jasper writer).
Expose `property var live: []`, `property var recent: []`, and
`readonly property int liveCount: live.length`.

Waiting PRs: do **not** duplicate the `gh pr list` poll — refactor
`ProposalsWidget.qml`'s probe result into this singleton (move the Process
here, expose `property var waiting: []`; ProposalsWidget renders
`Presence.waiting` and keeps its sentinel/hide-on-failure behavior).

### Step 3 — `PresencePanel.qml`

Copy the popup-window pattern from `CalendarPopup.qml` (same layer-shell
setup, same dismiss behavior). Three sections fed by `Presence.live`,
`Presence.waiting`, `Presence.recent`: lane name in `Theme.fontMono` +
peach-adjacent token (`Theme.warn` is sand; use `base09` via a semantic
read — check Theme.qml aliases, do not invent one), phrase/result in
`Theme.subtext`, url rows clickable via `Qt.openUrlExternally`. Empty
states: "idle — the machine is all yours" / "nothing needs you" / "no
recent work". Open triggers: click on Island (all states), click on
ProposalsWidget.

### Step 4 — adopters

One `claudeos_agent_done` call at the success point of each lane script:
jasper (`"insight refreshed"`), morning-desk (`"desk ready"` + artifact
path), auto-update (`"flake applied, VM green"`), self-heal (`"heal PR
opened"` + PR url), wish (`"wish PR opened"` + url — in `claude-wish` after
`url=` is parsed). Do not add failure-path calls in this order.

**Acceptance:** run `claudeos_agent_begin "testing presence" ; sleep 300`
in one shell and a real `claude-wish` in another → island shows the newest
phrase, panel lists both under Working; kill the sleep → entry gone next
poll. `rm` the ledger → panel shows empty state, no QML errors in `qs` log.
Truncate the ledger mid-line (`head -c 40`) → panel still renders (parse
failure keeps last good state). `quickshell_check` green throughout.

---

## WO-1b — notification router (highest care: this file owns the D-Bus name)

**Files:** `home/quickshell/Notifications.qml`, `home/quickshell/Toasts.qml`,
`home/quickshell/Island.qml` (queue badge), `home/hyprland.nix` (Routes.qml
generation), `lib/claude-script.nix` (`claudeos_notify` hints). Requires
WO-0 and WO-1a merged.

**The invariant, stated once:** every notification renders in exactly one
live surface (island peek | corner toast | quiet queue | presence ledger),
plus the history model always. If any code path can render two surfaces,
the order is not done.

### PROBE 1 — hints availability (do this before writing any code)

The router wants the `x-claudeos-lane` hint. Verify Quickshell exposes
notification hints: in a scratch copy of the deployed config, log
`JSON.stringify(notif.hints)` (or check `qs` docs via the object's
properties — print `Object.keys(notif)`) in `onNotification`, then run
`notify-send -h string:x-claudeos-lane:test hi`.

- **Hints readable** → routing key = `notif.hints["x-claudeos-lane"]`.
- **Hints absent from the API** → fallback contract (documented in the
  code): lanes set `--app-name=ClaudeOS:<lane>`; router splits appName on
  `:`. Update `claudeos_notify` accordingly and note the deviation in the
  PR body.

Whichever branch wins, `claudeos_notify` gains the lane tag and a new
`claudeos_notify_quiet` variant sets `x-claudeos-dest=quiet` (or
`:quiet` suffix under the fallback).

### Step 1 — routes table, generated from Nix

Mirror the `Keybinds.qml` heredoc block in `home/hyprland.nix` exactly (same
generation site, same "edit the .nix, never this file" comment). New
`routesEntries` Nix list above it, serialized with `builtins.toJSON`:

```nix
# Notification routing (WO-1b): first match wins; fields are optional
# matchers. dest ∈ island | toast | quiet | ledger.
routes = [
  { appMatch = "ClaudeOS"; laneDone = true; dest = "ledger"; }
  { destHint = "quiet"; dest = "quiet"; }
  { urgency = "critical"; dest = "toast"; }
  { hasActions = true; dest = "toast"; }
  { urgency = "low"; dest = "quiet"; }
  { dest = "island"; } # default: ambient peek
];
```

Generated `Routes.qml`: `Singleton { readonly property var rules: <json> }`.

### Step 2 — the router in `Notifications.qml`

`onNotification` becomes: build a facts object `{app, lane, destHint,
urgency, hasActions}`, walk `Routes.rules` first-match, then dispatch:

- `toast` → `notif.tracked = true` (nothing else — Toasts.qml already
  renders tracked).
- `island` → `root.posted(...)` (tracked stays false).
- `quiet` → push `{summary, body, appName, urgency}` onto a
  `quietQueue` list property; do not track, do not post.
- `ledger` → nothing (the lane's `claudeos_agent_done` already wrote the
  ledger; the notification exists only for non-ClaudeOS environments —
  suppress it). History insert stays unconditional, first line of the
  handler, before routing.

**Hard rule kept from today:** Critical always routes `toast` regardless of
any other rule — enforce in code before the table walk, so a bad routes
edit can never silence Critical.

### Step 3 — arbitration

- Fullscreen guard: PROBE 2 — confirm the focused-workspace/fullscreen
  signal available from `Quickshell.Hyprland` (the gotchas doc and
  Workspaces.qml show what IPC objects exist; find a boolean for "focused
  monitor has a fullscreen window", or derive from the active toplevel).
  While true, `toast`-routed non-Critical notifications divert to
  `quietQueue`.
- Flush: on fullscreen→false or hypridle unlock (v1: fullscreen only —
  idle needs no new plumbing to ship the rest), if `quietQueue.length > 2`
  emit ONE synthetic tracked notification "N quiet notifications while you
  were focused" whose click opens the notification center, else re-dispatch
  each through the router.
- Island badge: `Island.qml` shows `Presence`-style small badge with
  `Notifications.quietQueue.length` when > 0 (Theme tokens: `warn` on
  `surface`).

**Acceptance matrix** (each row: exactly one surface + history):

| Fire | Expect |
|---|---|
| `notify-send hi` | island peek |
| `notify-send -A a=A hi` | toast |
| `notify-send -u critical hi` | toast, double border |
| `notify-send -u low hi` | quiet badge increments |
| lane hint `…-dest:quiet` | quiet |
| `claudeos_agent_done` + its notification | ledger row only, no toast/peek |
| fullscreen mpv + 3 normal notifs | badge 3 → exit → one summary toast |
| corrupt Routes.qml rules to `[]` | everything toasts or peeks per hard rules; Critical unaffected |

---

## WO-2a — intent line, deterministic routes only

**Files:** new `home/quickshell/IntentLine.qml`, `shell.qml` (instantiate),
`lib/keybindings.nix` (one new `global` entry — pick `<Super>Return`… STOP:
`$mod, Return` is the terminal bind in `hyprland.nix`. Use
`<Super><Shift>Return` and record the choice in the PR body).

Clone `WishOverlay.qml` as the starting skeleton (shortcut, overlay window,
glow, Esc/click-away). Replace the single-purpose input with route
prediction on every keystroke:

- PROBE — desktop entries: check the gotchas doc / Quickshell docs for
  `DesktopEntries` (or equivalent) before coding; if no clean API, v1 app
  list = parse `ls /run/current-system/sw/share/applications/*.desktop`
  names once at startup via a Process.
- Route order (first match): `$` prefix → cmd · `resume |save as ` prefix →
  ctx (defer execution to WO-3; until then show the glyph but disable
  Enter with hint "contexts land in WO-3") · app-name prefix match → app ·
  trailing `?` or interrogative first word → ask · else task.
- Enter: app → launch via the entry (or `gtk-launch <id>`); cmd → spawn
  `$terminal -e fish -c '<cmd>; read'`; ask → existing `claude-ask-desktop`
  flow but non-interactive: call with the text as `$*` (it already accepts
  args? — READ `modules/common/system.nix` claude-ask-desktop first; if it
  only does zenity, add an args path in the same style as `claude-wish`'s
  `wish="$*"`); task → `claude-wish "<text>"` verbatim (v1: every task is a
  wish; the general task lane is WO-2b).
- The glyph row and hint line are plain Theme-styled QML; no model call
  anywhere in this order.

**Acceptance:** each route fires as specified with the intent line closing
first; `firefox` launch measured < ~200ms perceptually; Esc always
dismisses; fuzzel on SUPER+Space untouched; cheat sheet (Super+H) shows the
new bind automatically (it reads Keybinds.qml — verify).

---

## WO-2b — haiku router + general task lane

**Files:** `modules/common/system.nix` (new `claudeos-intent` +
`claude-task` scripts beside `claude-wish`), `IntentLine.qml` (task route
handoff). Requires WO-2a.

`claudeos-intent "<text>"`: only called for the `task` route. One
`claude_text haiku` call, contract-first prompt ending:

```
Your ENTIRE output must be exactly one line, one of:
ROUTE-WISH: <the wish, rephrased as a system-configuration change>
ROUTE-TASK: <imperative one-line task statement>
ROUTE-ASK: <the question>
```

Parse with the same `grep -oE` + fallthrough idiom as `claude-wish`'s
outcome parsing. Empty/garbled output → **fail open**: launch
`claude-quick` with the raw text prefilled (check how `claude-quick` is
invoked in `lib/keybindings.nix`/system.nix for the argument mechanism).
Never drop the text.

`claude-task` = `claude-wish`'s skeleton with these substitutions and
nothing else improvised:

- Branch prefix `task/`, notification strings s/wish/task/.
- Prompt: interpret the task; produce an **artifact** — a file under
  `~/Desk/tasks/<slug>/` (drafts, gathered data, a report) and/or a repo PR
  when the task is config-shaped; never send anything external.
- `--allowedTools` — this is the security judgment, pre-made; copy exactly:
  `'Read,Grep,Glob,Write,Edit,Bash(git fetch*),Bash(git status*),Bash(git diff*),Bash(git log*),Bash(git checkout -b *),Bash(git add *),Bash(git commit *),Bash(git push *),Bash(gh pr create*),Bash(nix build*--dry-run*),Bash(nix fmt*),Bash(hostname),WebSearch,WebFetch,mcp__nixos__*'`
  — i.e. the wish set + read-only web. **No** `Bash` wildcard, no mail/
  calendar/HA MCP tools, no `Bash(gh pr merge*)`. Widening this list is a
  STOP-AND-REPORT, not a judgment call.
- Output contract `TASK-DONE: <artifact path or PR url>` /
  `TASK-DECLINED: <reason>`; completion goes through `claudeos_agent_done`
  + a `quiet`-routed notification (WO-1b), not a toast.

**Acceptance:** "collect this week's nixpkgs breaking changes for our
inputs" → file artifact + ledger entry, no toast; "make the bar clock
blink" → routed WISH → wish PR; garbled router output (test by overriding
model to return prose — temporarily instruct via prompt) → claude-quick
opens with text intact.

---

## WO-4 — generated cards

**Files:** new `home/quickshell/cards/card.schema.json`, new
`home/quickshell/CardSurface.qml` + `CardRenderer.qml`, `shell.qml`,
`lib/claude-script.nix` (`claudeos_card`), registry file
`home/quickshell/cards/actions.json`.

Schema (v1, closed): top-level `{v:1, title, icon?, lane, sections:[…]}`;
section kinds exactly `text|kv|table|links|progress|actions`; `actions`
items `{label, do}` where `do` ∈ `open:<url> | copy:<text> | dismiss |
run:<name>` and `<name>` must exist in `actions.json` (v1 registry:
`open-morning-desk`, `open-notification-center` — two entries, grow by PR).

`claudeos_card FILE.json`: validate (`jq` structural checks are enough for
v1 — kind whitelist, `do` prefix whitelist, registry membership; a full
jsonschema tool is optional), then atomic install:
`install -m0644` to temp + `mv` into
`$XDG_RUNTIME_DIR/claudeos-cards.d/<lane>-<epoch>.json`. On validation
failure: `claudeos_notify "Card rejected" "<first jq error>"` and exit 0
(lane keeps going).

Renderer: `FileView`-or-poll (reuse the Agent.qml poll idiom at a slower
5s cadence) over the cards dir; `CardRenderer` is a `Column` of Loaders
switching on `kind` — every visual token from `Theme`; unknown kind renders
a one-line "unsupported section" row (forward compat, never a blank card).
Dismiss = delete the file. Surface opens from a bar glyph visible only when
cards exist (ProposalsWidget's visibility idiom).

**Acceptance:** hand-written valid card renders; `run:not-in-registry`
rejected at write time with notification; malformed JSON in the dir does
not blank the bar (`quickshell_check` with a garbage file present); reboot
clears cards (tmpfs); morning-desk emits its brief as a card behind a
`claude-os.morningDesk.card` option default off (one lane adoption, flag
so rollback is a toggle).

---

## WO-3 — task contexts (transporter-gated; run last)

**Precondition:** WO-2a merged. **Machine:** develop and soak on
`transporter` for 7 days of real use before enabling on `gti` (module gets
an `enable` option; gti flips it in a later one-line PR).

### PROBE (before any code, on transporter)

Capture and commit to the PR description: `hyprctl clients -j | jq '.[0]'`
(field names for class/workspace/pid), `hyprctl dispatch workspace
name:probe-test` behavior, whether `[workspace name:x] exec` rules exist in
this Hyprland version (check `hyprctl version` + the wiki via WebSearch —
grammar changed at 0.55 per CLAUDE.md, verify current). If dispatch-into-
named-workspace can't be made reliable, STOP — the fallback design
(numbered workspace + name overlay) is a design session's call.

### Build

`modules/apps/contexts.nix` with `claudeos-context` (mkClaudeScript):

- `save <slug>`: active-workspace clients → manifest
  `$STATE_DIR/claudeos/contexts/<slug>.json` per the plan's schema; term
  cwds via `readlink /proc/<pid>/cwd` of the client pid's newest child
  shell (probe: `pgrep -P`); browser windows recorded as
  `{kind:"app", class:"firefox"}` + window title only. Auto
  `git init`/`git commit` the contexts dir (its own repo — never nested in
  `$CLAUDEOS_DIR`).
- `restore <slug>`: dispatch to `name:<slug>`, launch missing items
  (`term` → `$terminal --working-directory=<cwd>` — verify ghostty's flag
  name via its docs first), skip items whose class already has a window on
  that workspace (idempotence). Never close or move existing windows —
  restore is strictly additive.
- `list` / `rm` trivial.

IntentLine: enable the ctx route → `claudeos-context restore <slug>`
(prefix-match slug against `list`). Workspaces.qml: render workspace
`name` when non-numeric (probe the IPC object's name field first).

**Acceptance (all on transporter):** save/reboot/restore round-trip
reassembles terminal cwds + apps on the named workspace; double-restore
adds nothing; restore with one app uninstalled skips it with a notification
listing what was skipped; `rm` + restore errors cleanly; nothing ever
closes a window. Soak: 7 days, zero focus-steal complaints, then the gti
enable PR.

---

## Order of execution and what NOT to parallelize

WO-0 → WO-1a → WO-1b → WO-2a → WO-4 → WO-2b → WO-3. (2b moved after 4:
task lanes should emit cards/ledger entries from day one rather than be
retrofitted.) Each order lands and is used for at least a couple of days
before the next starts. Never run two orders' branches concurrently — they
touch overlapping files (`Notifications.qml`, `claude-script.nix`) and the
merge conflicts would be paid in QML debugging.
