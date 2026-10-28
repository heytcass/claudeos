# Sonic palette + the Dream Lane

*Designed 2026-10-27. Order: Sonic palette ships first, then the Dream Lane.
The Dream Lane collector needs a few nights of data before the dreaming agent
has anything to say anyway.*

Two answers to "the system needs a little *something* more". Each extends a
doctrine that already exists rather than adding a new one:

- **Sonic palette.** "The system narrates itself" and the motion language,
  carried into sound. `lib/theme.nix` already has a colour twin (the palette)
  and a timing twin (the motion tokens). This adds an audio twin derived from
  both, so a theme change re-tunes the machine.
- **Dream Lane.** "Absence is the resource" and "the computer's unique
  knowledge is attention and activity", applied to the OS itself. Overnight,
  the system reads how it was actually used that day and proposes one
  improvement to itself.

---

## 1. Sonic palette

### Character (decided)

Soft glass: a sine with a quiet octave harmonic and a bell-like exponential
decay. Short, low, never a melody longer than three notes. The bar is the
system's one quiet voice, and sound follows the same rule.

### Derivation: nothing hand-tuned

| Sound property | Source in `lib/theme.nix` |
|---|---|
| Pitch set | The base16 accent hues (`base08`–`base0F`), each hue angle quantised onto a **major pentatonic** scale rooted at A3. Pentatonic means any two earcons played over each other are consonant. |
| Root / register | The palette's lightness: a lighter scheme sits higher (± a fourth). |
| Attack | A sixth of `instant` (15 ms), eased by `curves.standard`; the chime swells over `emphasis` along `curves.breathe` |
| Body / decay | `instant` for ticks, `standard` (280 ms) for notifications, `emphasis` + `quick` for the agent gestures |
| Pitch glides | Over `standard`: `curves.emphasized` for the rise (agent start), so it overshoots and settles like a window opening; `curves.standard` for the fall (agent finish), which decelerates into place. `exit` was the first idea, but it accelerates away, and finishing is an arrival. |
| Chime length | `breathe` (1400 ms), the same half-cycle as the Plymouth spark's breath |

Change the Stylix scheme or a motion token, rebuild, and every earcon moves
with it. Every musical number is decided in Nix at eval time: `lib/sonic.nix`
builds a JSON spec (pitches, timings, the motion curves verbatim). A small
in-repo Rust program, `pkgs/sonic-synth` (fundsp 0.23, `std` feature only),
renders the spec to WAVs at build time. Nothing is synthesised at runtime.

Why fundsp rather than sox: sox has no curve-shaped pitch sweep, so a glide
could only be faked as two staggered notes. fundsp drives the oscillator from a
control envelope, so the pitch follows the very cubic-bezier that Hyprland and
the bar animate with, with continuous phase. Amplitude is applied per sample
afterwards, because fundsp's control envelope samples every ~2 ms, too coarse
for a 3 ms tick attack. The envelope's jitter hash defaults to 0, so renders are
deterministic.

### Moments (decided)

| Event | Sound | Trigger |
|---|---|---|
| Agent start | One tone gliding home (the accent's pitch) → its fifth along `emphasized` | `Agent.active` false → true, debounced by `quick` |
| Agent finish | One tone gliding fifth → home along `standard` | `Agent.active` true → false, debounced by `quick` |
| Notification | One note. Timbre by urgency: low is the pure sine, quietest; normal adds the octave; critical adds a minor-third pair, played twice | `Notifications.posted`, **only** for the toast and peek routes. Quiet and ledger routes are silent by definition. |
| Volume / brightness | An `instant` tick. Pitch is chosen from 11 pre-rendered steps by the level (0 % = lowest) | `Osd.shown` |
| Login chime | Three-note pentatonic chord, swelling over `breathe` | Session start (once, from the Hyprland start hook) |

The login chime is not played during Plymouth: the initrd has no Pipewire.
It plays at session start instead, which is the first moment sound can exist.

### Quiet rules (decided)

- **While media plays** (any MPRIS player is `Playing`), everything is silent
  except the volume/brightness ticks, which are feedback the user asked for.
- **Do-not-disturb**: the bar has no explicit DND toggle today. The closest
  existing state is the notification arbitration's quiet path: a fullscreen
  focused window, and quiet-routed notifications. Sonic honours exactly that:
  silent under a fullscreen window, and silent for any notification that is
  not routed to a live surface. An explicit DND toggle was offered and not
  chosen; add one later if the implicit rule proves too implicit.

### Playback

A `Sonic.qml` singleton owns playback through `pw-play`, launched from a
`Process` with a store path baked in by the generated `Sonic` paths (the same
pattern as `Theme.qml`/`Motion.qml`). Each earcon is tagged with the
Notification media role, so Pipewire can duck or route it separately. Fire and
forget: a `pw-play` that is already running is not cancelled. Ticks are
rate-limited to one per `instant` (90 ms), so a held key doesn't stack
clicks.

**To verify during build:** that `pw-play --media-role` exists in the shipped
pipewire, and that `Agent.active` doesn't flap on a quick rebuild. If it
does, debounce by `quick` (160 ms) before the start sound.

### Files

As built: the WAVs ship inside the bar config as `sounds/`, and `Sonic.qml`
resolves them relative to itself (`Qt.resolvedUrl("sounds")`), so no generated
paths file is needed. Playback is `Quickshell.execDetached(["pw-play", ...])`.
Both open checks came back fine: `pw-play --media-role` exists, and the `quick`
debounce went in anyway, because `Agent.active` is a 2.5 s poll and a flap costs
a rise and a fall back to back.

- `lib/sonic.nix` (new): palette → pitches, motion → timings and curves; the
  JSON spec; a `runCommand` that renders it.
- `pkgs/sonic-synth/` (new): the Rust renderer (`default.nix`,
  `Cargo.toml`/`Cargo.lock`, `src/main.rs`).
- `home/hyprland.nix`: copy the sounds into the Quickshell config; add the
  login chime to the start hook.
- `home/quickshell/Sonic.qml` (new singleton): quiet rules, `play(name)`,
  `notify(urgency)`, plus the agent and OSD listeners.
- `Notifications.qml`: `Sonic.notify(...)` on the toast and peek routes.
  `shell.qml`: touch `Sonic` at startup.

---

## 2. Dream Lane

### Shape (decided)

One nightly run, while the machine is idle and on AC. It produces **at most
one** `dream/*` PR, often none, plus a morning card with the stable id
`dream`. The card is the receipt: what it noticed, the evidence in counts, and
why this change. Rung 1: propose only, never self-merge. No graduation is
planned. Any future rung would need its own narrow window plus a machine
check, per the doctrine.

### Signals (decided: all four), structured only

Never window titles, never screen or file contents, never command arguments.

| Signal | Collected how | Record |
|---|---|---|
| Window/app events | Hyprland Lua hooks: `window.open`, `window.close`, `window.move_to_workspace`, float toggles | `{t, ev, class, ws}`. Class only, never title. A close within 10 s of its open is flagged as a *bounce*. |
| Keybind usage | Every bind is built through `mkBind` in `home/hyprland.nix`. `hl.bind` accepts a Lua function (stub: `HL.Dispatcher\|function`), so `mkBind` wraps the dispatcher in a function that logs the key combo and then dispatches. | `{t, ev:"bind", keys}`. Binds that never fire are found nightly against the full bind list. |
| Shell command shapes | A fish `fish_postexec` hook | `{t, ev:"cmd", prog, flags, status}`. `argv[0]` plus flag tokens only; every non-flag argument is dropped before it is written. |
| System friction | Read at dream time, not collected: `journalctl` failed units, OOM kills, coredumps, `hypr_config_errors`, bar restarts | (queried) |

Logs are JSONL in `$XDG_STATE_HOME/claudeos/dream/<date>.jsonl`. They are
local and never committed, and are pruned after 14 days by the same nightly
unit.

**To verify during build:** whether Hyprland's Lua runtime exposes `io.open`.
If it does, the hooks append directly. If not, they hand off to a tiny
`claudeos-dream-log` via `hl.exec_cmd`, which is acceptable at human
keypress rates but checked for latency first. As CLAUDE.md warns, hook bodies
are invisible to `--verify-config`, so test them with `hyprctl eval` first.

### The dream

1. **Collect** (dumb script): aggregate the day's JSONL into counts, e.g.
   "`ghostty` opened 31×, bounced 6×", "SUPER+P never pressed in 14 days",
   "`git status && git diff --stat` shape typed 22×", "unit X failed 3×".
   The model only ever sees this summary, not the raw log.
2. **Dream** (one `claude -p` call, sonnet; see the cost note below) on a fresh
   branch, scoped like the wish lane. It gets the same `--allowedTools`
   allowlist as `claude-wish` plus read access to the summary. The prompt:
   pick the **single** highest-leverage, lowest-risk improvement the evidence
   supports, or none. Implement it, validate it (`nix build … --dry-run` for
   every host, `nix fmt`, and the Hyprland/QML checks if it touches those),
   then open the PR.
3. **Receipt**: `claudeos_lane_card dream "…"`, with the PR link as the
   card's action. A night with no PR still leaves a low-urgency card ("Slept
   on it: nothing worth changing"), so silence is distinguishable from
   breakage.

Candidate dream outcomes, for calibration: an `abbr` for a retyped command
shape, a window rule for an app that is always dragged to the same
workspace/float state, retiring or rebinding a dead keybind, a fix PR for a
recurring failed unit (overlapping self-heal, so the dream defers to self-heal
for anything already healing).

### Guardrails

- **Public repo.** The PR body and the card carry aggregate counts only, never
  log lines. The prompt says so, and the collector's summary is already only
  counts.
- **One PR per night.** It won't open a new one while a previous `dream/*` PR
  is unreviewed: it leaves a card instead ("yesterday's dream is still
  waiting").
- **No repeats.** A closed-unmerged dream PR's topic is recorded in the
  state dir, and the dream won't propose it again for 30 days.
- **Kill switch:** a module option `claudeos.dream.enable`, on for gti, off for
  transporter (the testbed has no real usage to learn from).

### Cost note: this refines the cost doctrine

The cost doctrine reserves opus for self-modification that fires at most
weekly. A nightly lane is more frequent than that, so the dream runs on
**sonnet**, like the wish lane it mirrors. This changes no conclusion in
PHILOSOPHY.md: it is the doctrine applied as written, and the PR that ships it
adds the Dream Lane to the proactivity doctrine's list of overnight work.

### Files

- `home/hyprland.nix`: `mkBind` logging wrapper; `window.*` hooks.
- `home/shell/fish.nix`: `fish_postexec` shape logger.
- `modules/apps/dream.nix` (new): collector/aggregator script, the dream
  `claude -p` call, a systemd user timer (nightly, `ConditionACPower`, idle
  check), pruning.
- `CAPABILITIES.md` and `docs/PHILOSOPHY.md`: document the lane.
