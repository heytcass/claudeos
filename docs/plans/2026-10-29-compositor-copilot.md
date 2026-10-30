# The compositor as co-pilot: four ways the bar talks back to Hyprland

**Status:** design, 2026-10-29. Nothing built yet. Spike findings below were run
against the live gti session (Hyprland 0.56.2, Lua config).

## The premise

Across ~9,300 lines of QML the bar consumes exactly **one** raw Hyprland event
(`fullscreen`, in `Notifications.qml`); everything else is the polled
`Hyprland.*` model, and every write is a `Hyprland.dispatch` focus. The bar is
a very good *viewer* of the compositor.

Hyprland's Lua config turns that into a two-way relationship. The compositor
now exposes runtime window rules matched on **tags**, per-window `pid`, Lua
**layout providers**, and events for submaps and screen sharing. So the bar
can do more than show compositor state: it can steer how windows look and
where they go — without a plugin, and without ever evaluating model output.

Four directions, smallest first:

| # | Name | One line |
|---|------|----------|
| A | Screen-share privacy mode | Sharing your screen hides what shouldn't be shared, and says so |
| B | Submap HUD | Modal keybindings you can see while you're in them |
| C | Agent-state chrome | A window's *border* tells you its Claude session is working or waiting on you — **deferred** (see C) |
| D | Intent layouts | `compare`, `reading`, `focus` as real Lua layouts, carried by contexts |

## The one design rule: rules live in Nix, the shell only moves tags

Every visual effect here is a **static, named window rule in `home/hyprland.nix`**
— rendered from the Stylix palette, checked by `--verify-config` at rung 3,
present from the first frame. At runtime the bar only adds and removes **tags**
on windows (and, for D, picks a workspace's layout). Consequences:

- Nothing is injected with `hyprctl eval` in the steady state. A reload can't
  lose behaviour, and there is no runtime Lua to go stale.
- The worst a bar bug can do is leave a stale tag — a wrong border colour,
  cleared by the startup sweep (below) or by closing the window.
- Colours obey the theming rule for free: the rules are Nix, so they use
  `config.lib.stylix.colors` like every other border.

## Spike findings (2026-10-29)

| Claim | How checked | Result |
|-------|-------------|--------|
| `border_color` is a valid window-rule effect under Lua | `hypr_config_check` with the rule; a bogus field in the same position is rejected (`unknown field`) | ✅ grammar real, check can fail |
| A tag added **at runtime** re-triggers a tag-matched rule | Registered `match = { tag = "agent-waiting" }` rule via `hyprctl eval`, tagged the Claude window with `hl.dsp.window.tag({ tag = "+agent-waiting", window = "address:…" })`, read `hyprctl getprop address:… active_border_color` | ✅ `ffd97757` → `ffff0000` → back to `ffd97757` on `-agent-waiting`. Spike rule disabled after |
| `hyprctl getprop` reads a window's *effective* border | same | ✅ — this is the verification hook for C's tests |
| Gradient border + `borderangle` loop animation parses | `hypr_config_check`: `hl.animation({ leaf = "borderangle", style = "loop", … })` + two-colour `border_color` | ✅ parses; **not yet seen** (visual check is Phase 0) |
| `hl.layout.register(name, { recalculate, layout_msg })` | `hyprctl eval` with a trivial column layout | ✅ registers; **not yet applied** to a workspace |
| Per-workspace layout | stub: `HL.WorkspaceRuleSpec` has `layout` + `layout_opts`; `hl.dsp.layout` dispatcher exists | ✅ in API; untested |
| Submaps in use today | `hyprctl binds -j` | **None.** 58 binds, all root, 0 with descriptions |
| Windows carry `pid` and `tags` | `hl.get_windows()` via `hyprctl eval` | ✅ |
| Where Claude sessions live | `ps` | Every live `claude` is a child of the **desktop app** (pid 1477 → `disclaimer` → `claude`). No terminal sessions right now |

Free SUPER-only keys: `B D E G J K M N U X Y Z`.

Verifier quirk worth fixing separately: `hypr_config_check` reports a real
rejection (`unknown field`) as **UNVERIFIABLE (rc=1)**. The verdict text is
wrong even though the parser output is right. Read the output, not the verdict,
until that's fixed.

---

## A. Screen-share privacy mode

**What you get.** The moment a screen share starts, the bar goes "on air":
toast *bodies* are held (titles only, or nothing), Jasper's insight, the Shelf
and generated Cards are hidden, and the island shows a small on-air face. If a
single window is being shared, it gets an `on-air` tag → a base08 border, so
you can see *what* is going out. When the share ends, everything comes back.

**Why it matters.** A whole-monitor share includes the bar. Today Jasper's
personal insight line and every notification body would be broadcast.

**Wiring.**
- Signal: the `screencast` raw event on socket2 (same `Hyprland.rawEvent`
  channel `Notifications.qml` already reads for `fullscreen`). The Lua
  equivalent is `screenshare.state`. **Payload format unconfirmed** — the
  legacy form is `screencast>>STATE,OWNER` (owner 0 = monitor, 1 = window).
- New `Sharing.qml` singleton: `property bool onAir`, `property string owner`.
- `Notifications.qml` arbiter gets a third boundary beside fullscreen and idle.
- `Jasper`, `ShelfPopup`, `CardSurface`, `Toasts` bind `visible: !Sharing.onAir`
  (or a redacted face).
- Rule in `hyprland.nix`: `{ name = "on-air"; match.tag = "on-air"; border_color = "rgb(${c.base08})"; }`.

**Validation.** Rung 3 (`quickshell_check`, `hypr_config_check` for the rule)
+ 4. Behaviour check needs you to start one real share (Phase 0).

**Open:** does the portal emit a window *address* for window shares, or only
the owner flag? If only the flag, the `on-air` border is monitor-share only.

## B. Submap HUD

**What you get.** Modes for the desktop. Press e.g. SUPER+M and the island
morphs into a compact grid of the keys that are live *right now* (h/j/k/l move,
shift resizes, f floats, p pins, Esc leaves). The cheat sheet is the static map;
this is the live one, shown only while it's true.

**The catch the spike found:** there are no submaps today, so B is really two
pieces — the HUD, and the first submaps worth having.

**Wiring.**
- `lib/keybindings.nix` (the single source that already generates the binds,
  `claudeos` help and `Keybinds.qml`) gains an optional `submap` field.
  `home/hyprland.nix` emits `hl.define_submap(name, "reset", fn)` per group —
  `"reset"` makes one-shot modes drop back after a single action; persistent
  modes (resize) get an explicit Esc bind, **generated automatically for every
  submap** so it's impossible to ship a mode you can't leave.
- Pass each entry's `short` into Hyprland's bind `description` option, so
  `hyprctl binds -j` becomes self-documenting too (`has_description` is 0 today).
- `Island.qml` gets a `submap` face, driven by the `submap` raw event, reading
  `Keybinds.qml` filtered by `submap`.

**First submaps (proposal):** `window` (move/resize/float/pin/group — the
mouse-free version of SUPER-drag), and `context` (save / resume / shelf).

**Validation.** Rung 3 for every new bind line (bind option names are the one
thing `--verify-config` doesn't check — read them by eye) + 4. Behaviour: enter
and leave every mode by keyboard before landing.

## C. Agent-state chrome — deferred

**Decision (2026-10-29): not building the borders.** All Claude work happens
in the desktop app, so every session collapses onto one window, and that
window already shows its own state. A border on it would repeat the app
to someone who is usually looking straight at it.

**What survives:** persisting `waiting`. Today it is only a sound, so the bar
can't tell "working" from "waiting on you". Writing `state = "waiting"` in the
hook (cleared on `refresh`/`end`) lets `Agent.qml`/`Presence.qml` say *waiting
on you* when the app is on another workspace or behind something. That's a
small change to `claudeos-agent-hook` (rung 5, since it's an embedded script) and
two QML bindings, and it needs no compositor work. Fold it into Phase 1.

**Revisit if** Claude sessions start living in their own windows (terminal
`claude`, or lanes that open a window). The design below then works unchanged,
and the tag-rule spike already proved the mechanism.

**What it would have done.** The window that hosts a Claude session changes its border by
the session's state:

| State | Border | Source |
|-------|--------|--------|
| working | slow-rotating two-tone gradient (base0D → base0C) | `UserPromptSubmit` → `claudeos-agent-hook begin` |
| waiting on you | solid base0A, no motion | `PreToolUse:AskUserQuestion`, permission/elicitation `Notification` → `waiting` |
| idle / done | the normal border | `Stop` → `end` |

The workspace pill holding that window picks up the same tint, so a waiting
session on workspace 5 shows from workspace 1 too.

**What exists.** `claudeos-agent-hook` (`home/claude-code.nix`) already writes
`$XDG_RUNTIME_DIR/claudeos-agent.d/claude-<session_id>` on begin and removes it
on end, and `Presence.qml` polls that directory every 2.5 s. **Missing:**
`waiting` is only a sound (nothing persisted), and nothing records which
process the session belongs to.

**Wiring.**
1. Hook: on `begin`, also write `claude-<sid>.json` — `{ state, since,
   ancestors: [pids] }`, the ancestor chain walked once from `/proc/$PPID/stat`.
   `waiting` sets `state = "waiting"`; `refresh` (PostToolUse — the question was
   answered) sets it back to `"working"`; `end` removes both files.
2. `AgentChrome.qml` (or an extension of `Presence.qml`, which already polls
   the dir): intersect each session's `ancestors` with `Hyprland.toplevels`'
   pids. Most urgent state wins per window (`waiting > working`). No extra
   processes — the pid walk happened once in the hook.
3. Apply by tag diff: `hl.dsp.window.tag({ tag = "+agent-working", window = … })`
   only when a window's state *changes*.
4. **Startup sweep:** on bar start, strip `agent-*` tags from every window, so a
   crash mid-session can't leave a ghost border.
5. Rules + the `borderangle` loop animation in `home/hyprland.nix`.

**The honest limitation.** Today all your sessions live in one window — the
desktop app. Per-window chrome there means "the app window is waiting if *any*
session is". That's useful when the app is behind something or on another
workspace, and useless when you're looking at it. Terminal `claude` sessions
(and any future lane that opens a window) get true per-window state for free.

**Cost check (Phase 0).** A `loop` animation redraws continuously while it
runs. Measure GPU wakeups / package power on gti with the loop on vs off. If
it's meaningful, keep the rotation but run it only while a window is tagged
`agent-working` — the one place a small runtime config toggle would be justified.

## D. Intent layouts

**What you get.** Layouts named after what you're doing, not the tree shape:

- **reading** — one centred column at a comfortable measure; everything else
  off to the sides, narrow.
- **compare** — the two most recent windows 50/50; the rest stacked in a thin
  column on the right.
- **focus** — one window large, the rest a strip.

Say "compare these" in the intent line (SUPER+R), or let a context restore
with its layout. Saved contexts carry `layout` in their manifest; `restore`
already names the workspace after the context, so it sets a workspace rule
`{ workspace = "name:<slug>", layout = "compare" }` alongside.

**Wiring.**
- One Lua file of layouts, rendered by `home/hyprland.nix`, each a
  `hl.layout.register(name, { recalculate, layout_msg })`. `ctx:column`,
  `ctx:split` and `ctx:grid_cell` do most of the geometry.
- `layout_msg` handles small verbs (`swap-primary`, `widen`, `narrow`).
- Claude-authored layouts are **data, not Lua**: a ratio spec (`{ primary =
  0.62, rest = "column-right" }`) interpreted by one hand-written engine
  layout — the same "never evaluate model output" rule `CardRenderer.qml` keeps.
- Preview: if `layout_msg` can return the computed boxes as a string to the
  caller (unconfirmed), the bar draws ghost outlines from the *same* geometry
  before you commit. If it can't, skip previews rather than duplicating the
  math in QML.

**Blast radius.** Layouts are opt-in per workspace, never `general.layout`.
dwindle stays the default. A `recalculate` that throws must not leave windows
unplaced — Phase 0 checks what Hyprland does when a Lua layout errors.

---

## Phases

| Phase | Contents | Needs you |
|-------|----------|-----------|
| 0 · spikes | Start one screen share and read the `screencast` payload; apply the spike layout on a scratch workspace with three throwaway windows; make a layout throw on purpose; check whether `layout_msg`'s return reaches `hyprctl` | yes — ~10 min, mostly looking |
| 1 · A + B | `Sharing.qml` + arbiter boundary + rule; `submap` field, generated submaps + Esc, HUD face; persisted `waiting` state in the bar (from C) | final look |
| 2 · D | layout file, context manifest field, intent routes, previews if possible | design review of the three layouts |

Validation per phase follows CLAUDE.md's table: QML → rung 3; new Hyprland
lines → `hypr_config_check` each + rung 4; hook change (embedded shell in
`writeShellScriptBin`) → rung 5.

## Leads not taken (yet)

- **`hl.dsp.event`** — a dispatcher that appears to emit a custom event. If it
  lands on socket2, it's a clean Lua→bar channel for hooks that live in the
  compositor. Untested.
- **`decoration.screen_shader`** — screen-wide ambient state (desaturate all but
  the focused window in focus mode; bedtime grayscale). Costs direct scanout.
- **`input.keyboard.key`** — typing cadence as a flow signal for the arbiter.
  Needs a privacy decision in PHILOSOPHY.md first (timing only, keycodes never
  leave the compositor).
- **Attention ribbon, window-anchored callouts, Claude's own pointer** — from
  the same brainstorm; each needs its own design pass.

## Decisions needed

1. ~~C on the desktop app window~~ — **decided:** deferred; only the persisted
   `waiting` state is built.
2. ~~Working = motion?~~ — moot while C is deferred.
3. ~~Submap entry keys~~ — **decided:** SUPER+M opens `window`, SUPER+G opens `context`.
4. ~~Share redaction depth~~ — **decided:** titles only; bodies are held until the share ends.
