# Implementing the AI-Native HMI: a phased plan

*Implementation plan, 2026-07-17. Companion to
`2026-07-17-ai-native-hmi-vision.md`, which argues the five-year prediction
and the five-stage staircase. This document is the engineering plan for
Stages 1–4 on the existing stack: Quickshell bar + Hyprland + the
`lib/claude-script.nix` lane pattern. Stage 5 (the second seat) is sketched
only as preconditions — it should not be designed in detail until Stages 1
and 4 exist, because it depends on their surfaces.*

## Design ground rules (from PHILOSOPHY.md, restated as constraints)

1. **No daemon, no second brain.** Everything below is lanes (timer/event →
   dumb collectors → at most one `claude -p`), files on existing contracts,
   and deterministic QML. If a phase seems to need a resident process, the
   design is wrong.
2. **Chrome is deterministic; only content is generated.** QML never
   evaluates model output. Model output enters the bar exclusively as
   *data* — plain text or schema-validated JSON — rendered by handwritten
   components.
3. **Cost doctrine:** haiku-class for high-frequency routing, sonnet-class
   for rare agentic work, everything event-driven. A keystroke or a state
   change may trigger a call; a timer alone may not (significance gates).
4. **Daily-driver rule:** every phase must leave the desktop *better* on day
   one, keep existing muscle memory working until the replacement is proven,
   and be revertible by generation rollback.
5. **Ring discipline:** shell components, lane scripts, keybindings = ring 1
   (this repo). Task-context manifests and card instances = ring 2 (mutable
   user state under `$STATE_DIR` / `$XDG_RUNTIME_DIR`), never declared in
   Nix.
6. **Validation:** QML/Hyprland changes are invisible to `nix build` — every
   phase ships with the `quickshell_check` / `hypr_config_check` /
   `/qml-dial-in` loop, and anything that manipulates live windows (Stage 3)
   proves out on transporter first.

## The file contracts (existing and new)

Everything communicates through files, like today. Current contracts:

| Path | Writer | Reader |
|---|---|---|
| `$XDG_RUNTIME_DIR/claudeos-agent.d/<pid>` | `claudeos_agent_begin` | `Agent.qml` (newest fresh file, line 1) |
| `$MONITOR_CACHE_DIR/jasper-insight.txt` | jasper lane | `Jasper.qml` |
| `$MONITOR_CACHE_DIR/daily-brief.txt` etc. | monitor/desk lanes | fish MOTD, morning desk |
| `gh pr list` (poll) | — | `ProposalsWidget.qml` |

New contracts introduced by this plan (all follow the same shape — writer
helper in `lib/claude-script.nix`, polling/`FileView` singleton in QML):

| Path | Purpose | Phase |
|---|---|---|
| `claudeos-agent.d/<pid>.json` | sidecar: lane name, state, detail, links | 1a |
| `$MONITOR_CACHE_DIR/presence-done.jsonl` | ledger of recently finished lane work | 1a |
| `$XDG_RUNTIME_DIR/claudeos-cards.d/*.json` | ephemeral generated surfaces | 4 |
| `$STATE_DIR/claudeos/contexts/<slug>.json` | task-context manifests | 3 |

---

## Phase 1a — Presence: the second-operator surface

**Goal:** one glanceable answer to "what is the other operator doing, what
has it done, what is it waiting on?" Today that's three fragments: Agent.qml
(one activity line), ProposalsWidget (PR count), and nothing at all for
completed work.

**Changes:**

- `lib/claude-script.nix`: teach `claudeos_agent_begin` to also write
  `$CLAUDEOS_AGENT_DIR/$$.json` — `{"lane": "<name>", "phrase": "<line 1>",
  "started": <ts>}`. Line-1-of-`<pid>` stays byte-identical, so the existing
  Agent.qml keeps working unmodified during the transition (and forever, as
  the fallback). Add `claudeos_agent_done "<one-line result>" [url]`, which
  appends to `presence-done.jsonl` (capped: keep last ~20 lines via
  `tail`-rewrite) before the EXIT trap clears the presence file.
- New `home/quickshell/Presence.qml` (singleton): polls the agent dir like
  Agent.qml but parses *all* fresh entries plus the done-ledger tail and the
  existing proposals poll result into one model:
  `{ live: [{lane, phrase, age}], waiting: [{number, title}], recent:
  [{lane, result, url, ts}] }`.
- New `home/quickshell/PresencePanel.qml`: a popup (same layer-shell pattern
  as CalendarPopup) opened by clicking the island while in `agent` mode or
  the ProposalsWidget glyph. Three small sections: **working** (live lanes,
  breathing accent), **waiting on you** (agent PRs — click opens the PR),
  **recently finished** (last few ledger lines — click opens the artifact).
  This is prediction 6's "trust becomes chrome" in its first concrete form:
  provenance and audit one click from the bar.
- `Island.qml`: when >1 lane is live, the agent line becomes "2 lanes
  working" with the newest phrase; otherwise unchanged.

**Adopters (same PR or fast-follow):** jasper, morning-desk, self-heal,
auto-update, wish — each adds one `claudeos_agent_done` call with its
artifact link. Five one-line diffs.

**Non-goals:** no model calls anywhere in this phase; no notification
changes yet.

**Acceptance:** kick off a wish and a rebuild simultaneously → island shows
both; panel lists both live, then shows the wish PR under *waiting*, then
under *recent* after merge. `quickshell_check` green; bar survives with the
ledger file absent, empty, or truncated mid-line.

## Phase 1b — Notification routing & arbitration

**Goal:** every notification renders in **exactly one live surface** (plus
the history center, always), the surface matches the need, and
interruptions earn their moment ("one thing, never a feed" applied to
toasts). Deterministic logic only.

**Why this is tractable:** since the mako rip-out the shell *is* the
notification daemon — `Notifications.qml` owns
`org.freedesktop.Notifications`, so every notification already flows
through one function (`onNotification`). Today that function makes an
overlapping split: `tracked = actionable` sends action/Critical
notifications to the corner toasts, while `posted` fires for *everything*
and the island peeks everything posted — so actionable notifications render
twice. The dispatch point is right; it just needs to become a real router.

**Step 0 — kill the duplication (one-line-class fix, can land ahead of
everything else):** emit `posted` only for notifications that are *not*
tracked. Ambient notifications peek on the island; actionable ones own the
corner; nothing renders twice. (Alternative with the same effect: pass
`tracked` through `posted` and let the island ignore tracked ones.)

**The router.** `onNotification` resolves each notification to one
destination:

| Destination | Meant for | Today's signal |
|---|---|---|
| **Island peek** | ambient/FYI — glance and gone | default (no actions, urgency ≤ normal) |
| **Corner toast** | needs a decision *now* — buttons, Critical | `actions.length > 0` or Critical |
| **Quiet queue** | FYI that shouldn't interrupt — flushed at idle/unlock as one summary | `urgency = low`, or lane-hinted |
| **Presence ledger (1a)** | lane work product — the panel is its home | `x-claudeos-lane` hint + done-class |
| **History center** | memory | everything, unconditionally (as now) |

Routing inputs, in priority order: explicit ClaudeOS hints (`claudeos_notify`
grows `-h string:x-claudeos-lane:$LANE` and an optional
`x-claudeos-dest` for lanes that know where they belong), then urgency +
actions, then per-app rules. The per-app rules live as a small **declarative
routing table generated from Nix** (a `Routes.qml` singleton or routes JSON
emitted by `home/hyprland.nix`, defaults mirroring today's heuristic) — the
routing policy becomes ring-1, reviewable config rather than logic buried in
QML, and adjusting where an app's notifications land becomes a one-line
diff (or a wish).

**Arbitration (per-destination timing, after routing):**

- **Defer, don't drop:** while any window on the focused monitor is
  fullscreen (Hyprland IPC via `Quickshell.Hyprland`), corner toasts below
  Critical divert to the quiet queue; flushed when fullscreen ends,
  collapsed into one summary toast if >2 queued ("3 quiet notifications
  while you were focused" → opens the notification center).
- **Lane completions never toast** once 1a lands — the PresencePanel
  *recent* section is their home, and the toast budget is reserved for
  things needing action. This retires a class of "the machine narrating at
  you" noise.
- **Boundary delivery (cheap v1):** the quiet queue flushes on hypridle
  idleness or unlock. Full task-boundary detection (window-switch
  heuristics) is deliberately *not* attempted yet: the simple version must
  prove daily-driver value first.

**Acceptance:** an actionable notification toasts and does *not* peek the
island; an ambient one peeks and does not toast; both appear in history
exactly once. Play a fullscreen video, fire a normal notification → arrives
after leaving fullscreen as a summary; Critical punches through
immediately. A lane completion appears in the panel only. Re-routing an
app's notifications requires only a routes-table edit.

### Where notifications go long-term

The end state (Phases 1b + 4 together) is that "notification" stops being a
popup category and becomes **routing metadata on a state change**. The
D-Bus notification stays the universal ingress — every app already speaks
it, and the shell owning the server means we classify at the door — but
what renders diverges into species: *ambient narration* (island peek, the
machine's murmur), *action requests* (corner toasts, which Phase 4 upgrades
from text+buttons to schema-validated **cards** when the payload carries
one — a real diff to review, a form to fill, not four truncated lines),
*work product* (the presence ledger and cards — never interrupts, always
waiting), and *memory* (the history center, which inherits everything). The
proactivity doctrine's hierarchy — one thing, ranked below, minutiae
smallest — becomes literally spatial: the island is the one thing, the
corner is the ranked actionable set, the panel is everything below. Voice
or remote surfaces later slot in as just another destination in the same
routes table.

## Phase 2 — The intent line

**Goal:** one input that takes a sentence and routes it, absorbing the
launcher's job without breaking it. SUPER+Space keeps launching fuzzel until
the intent line has earned the bind (daily-driver rule); the intent line
ships on **SUPER+Enter**-class real estate first (exact bind chosen in
`lib/keybindings.nix`, the single source of truth — it flows to Hyprland,
the cheat sheet, and `claudeos` help automatically).

**Architecture — deterministic first, model second:**

- New `home/quickshell/IntentLine.qml`: evolves WishOverlay's shell (global
  shortcut, centered capsule, agent-glow language). As you type it shows the
  *predicted route* as a leading glyph, and deterministic routes resolve
  with **zero model calls**:
  - input matches an installed app name (prefix/fuzzy over desktop entries —
    reuse fuzzel's cache or `Quickshell` desktop-entry API) → **app** route,
    Enter launches. This keeps launcher latency at launcher speed.
  - leading `$` → **command** route (run in `$terminal`).
  - trailing `?` or leading "what/why/how" → **ask** route (existing
    `claude-ask-desktop` path: answer as notification).
  - anything else → **task** route (below), with a hold-Enter/Tab override
    to force a different route. Every route is visible before commit —
    predictable, auditable, no surprises.
- New `modules/apps/intent.nix` providing `claudeos-intent` via
  `mkClaudeScript`: the **task** route's backend. For ambiguous input (only
  when deterministic classification declined), one `claude_text haiku` call
  with a strict one-line contract — `ROUTE: app|cmd|ask|wish|task` +
  payload — failing open to `claude-quick` with the text preloaded (an
  unroutable intent lands in the interactive brain, never on the floor).
- **Task route = the wish lane generalised.** `claude-wish` stays exactly
  what it is (repo-PR route) and becomes one arm of `claudeos-intent`:
  wishes about *this machine's configuration* go to the wish lane
  unchanged; other tasks ("draft a reply to the plumber", "collect the
  refi docs") spawn a task lane — same skeleton as wish (presence marker,
  headless `claude -p` with a scoped `--allowedTools`, artifact + PR/file
  output, notification via the 1b rules, `claudeos_agent_done` link). Trust
  ladder rung 1: every task ends in a reviewable artifact, never a sent
  email or a pushed main.

**Sequencing within the phase:** 2a ships the overlay with only
deterministic routes (a better fuzzel, honestly assessed); 2b adds the haiku
router + task lane. If 2a doesn't beat fuzzel in daily feel after a week, 2b
waits until it does.

**Acceptance:** "firefox" launches in <150ms with no model call; "$btop"
opens a terminal; "why is my battery draining?" returns a notification
answer; "I wish the bar showed moon phase" produces a `wish/*` PR; a
genuinely ambiguous sentence reaches the haiku router, and a router failure
lands in `claude-quick` with the text intact. Fuzzel still on SUPER+Space
throughout.

## Phase 3 — Task contexts

**Goal:** named, durable, agent-preparable working contexts; workspaces
become projections of them. This is the riskiest phase (live window
manipulation) — **transporter first, gti only after a week of daily use.**

**Manifest (ring 2 — `$STATE_DIR/claudeos/contexts/<slug>.json`):**

```json
{ "name": "refinance", "created": 1789000000, "updated": 1789000000,
  "items": [
    {"kind": "app",  "class": "firefox", "urls": ["https://..."]},
    {"kind": "term", "cwd": "~/finance/refi", "cmd": null},
    {"kind": "file", "path": "~/finance/refi/rates.ods"}
  ],
  "notes": "waiting on payoff letter" }
```

The contexts dir is a standalone git repo (auto-init, auto-commit on save by
the CLI) — history and diffability without polluting the system repo or
declaring ring-2 state in Nix.

- New `modules/apps/contexts.nix` providing `claudeos-context`
  (save/restore/list/rm):
  - **save**: snapshot the *current workspace* — `hyprctl clients -j`
    filtered to the active workspace for window classes; terminal cwds via
    the child shell's `/proc/<pid>/cwd`; browser URLs are best-effort v1
    (window titles only; a tab-level integration is a separate decision, not
    smuggled in here). The honest v1 contract: **a context restores your
    tools and places, not pixel-perfect app state.**
  - **restore**: `hyprctl dispatch workspace name:<slug>`, then launch each
    item into it (`[workspace name:<slug>] exec` rules), skipping items
    already present. Idempotent: restoring an open context focuses it.
- `Workspaces.qml`: render named workspaces by name (they already come
  through Hyprland IPC); active-context name joins the island's idle mode at
  low emphasis.
- Intent line grows two deterministic routes: `save as <name>` and
  `resume <name>` (prefix-matched against the contexts dir — no model call).
- **Agent preparation** (the payoff): lanes may *write* manifests. The
  morning desk's prepared artifacts become a `morning` context you `resume`
  instead of a folder you go find; a task lane that gathered documents
  leaves a context pointing at them. One helper (`claudeos_context_emit`) in
  `claude-script.nix`, same validation as the CLI.

**Acceptance:** save a two-terminal + browser workspace, reboot, `resume
refinance` → named workspace reassembles with cwds intact; restore is
idempotent; a lane-written manifest restores identically; malformed manifest
→ clear error, no half-restored workspace.

## Phase 4 — Generated surfaces (cards)

**Goal:** the long tail of single-use UI — comparisons, dashboards, forms —
generated as *data*, rendered deterministically, gone when dismissed.

- **Schema** (`home/quickshell/cards/card.schema.json`, repo-tracked):
  `{title, icon?, urgency?, sections: [...]}` where a section is one of
  `text`, `kv` (label/value rows), `table` (bounded columns), `links`,
  `progress`, `actions`. Actions are a closed set: `open <url>`,
  `copy <text>`, `dismiss`, `run <name>` where `<name>` must exist in a
  repo-tracked registry of pre-declared commands. **No free-form exec, ever;
  a model can propose an action only from the registry.**
- **Writer**: `claudeos_card <file.json>` in `claude-script.nix` — validates
  against the schema (bundled `check-jsonschema` or a jq validator) and
  atomically installs into `$XDG_RUNTIME_DIR/claudeos-cards.d/`; an invalid
  card degrades to a plain notification carrying the validation error (the
  lane hears about its own malformed output; the bar never renders junk).
  Runtime dir = tmpfs: cards die on reboot by construction — ephemerality
  for free.
- **Renderer**: `CardSurface.qml` (one layer-shell window listing live
  cards, opened from the island / a bar glyph when cards exist, subject to
  the 1b arbitration rules) + `CardRenderer.qml` (pure schema→Theme-styled
  QML mapping, every colour and metric from the `Theme` singleton).
- **First adopters**: morning desk (its brief as a `kv`+`links` card),
  jasper click-through (insight + the reasoning context as a card), a task
  lane's "compare these quotes" table. One new lane capability, three
  existing lanes exercising it.

**Acceptance:** hand-write a card json → renders; corrupt it → notification
fallback with the schema error, bar intact (`quickshell_check` green);
morning desk card appears at first login, dismiss removes the file; an
`actions.run` name not in the registry fails validation.

## Stage 5 preconditions (not planned here)

The second seat — the agent visibly driving real apps in its own workspace —
is deliberately unplanned until: (a) PresencePanel is daily-driver habit
(you already trust the narration), (b) task lanes have a track record of
artifact quality (rung history to point at), and (c) contexts exist (the
agent needs a workspace-shaped place to work that isn't yours). Revisit as
its own plan doc then; the likely shape is a `special:claude` workspace plus
`hyprctl dispatch` focus handoff, rung-gated like every lane.

## Sequencing, sizing, and risk

Order: **1a → 1b → 2a → 2b → 4 → 3.** (4 before 3: cards are pure
additive QML + one helper with no live-window risk, and they make task lanes
visibly better, which builds the case for contexts. 3 carries the real
integration risk and wants transporter soak time.)

Each phase is one PR-sized unit (1a may split into scaffolding + adopters).
All land as `claude/*` branches for human review — none of this fits the
rung-2 self-merge window (multi-file, QML), which is correct: interface
changes deserve the human rung.

| Risk | Mitigation |
|---|---|
| One broken QML file blanks the bar | `quickshell_check` before every rebuild; new surfaces are separate files loaded from `shell.qml`, failures isolated by the existing sentinel/`@`-contract idioms |
| Intent line regresses launcher speed | deterministic app route bypasses the model entirely; fuzzel keeps its bind until 2a proves out |
| `hyprctl` restore misbehaves (focus steal, wrong monitor) | transporter-first; restore is idempotent and additive; contexts never close windows |
| Card actions as an injection surface | closed action registry, schema validation at write time, renderer never evals |
| Presence ledger grows unbounded | `tail`-rewrite cap in the writer, age filter in the reader (same idiom as agent.d's 60-min rule) |
| Polling creep in the bar | new singletons reuse existing poll cadences (agent.d 2.5s, gh 30s-class); cards/contexts read on open or via `FileView` watch, not new timers |

## What this plan deliberately does not build

No resident daemon; no second brain; no content surveillance (contexts
snapshot window classes, cwds, and titles — never document contents or
keystrokes); no browser-tab deep integration in v1; no voice input (the
intent line is the keyboard-shaped groundwork voice would later feed); no
replacement of fuzzel, mako-style notification history, or any working
muscle memory until its successor has demonstrably earned the bind.
