# ClaudeOS Capabilities

ClaudeOS is a Claude-native NixOS system where Claude is integrated at every layer: desktop keybindings, shell commands, MCP servers, Claude Code agents/skills/hooks, and background monitoring with self-healing. This document is the single reference for what's available and when to use it.

Run `claudeos` in a terminal to see the user-facing quick reference.

## MCP Servers

### nixos (`mcp-nixos`)

Ground truth for everything Nix — two consolidated tools (`nix`, `nix_versions`) covering NixOS options, 130K+ packages, home-manager/darwin/nixvim options, Nix functions (noogle), NixOS Wiki, FlakeHub, and package version history with nixpkgs commit hashes (NixHub). Pinned as the `mcp-nixos` flake input; binary installed by `home/claude-code.nix`.

**When to use:** Before writing ANY option name or package reference — never from memory. Also for "which nixpkgs commit had version X" questions (`nix_versions`).

### system-health (`mcp-system-health`)

System diagnostics plus runtime config validation — checks `nix build` cannot do.

| Tool | Purpose |
|------|---------|
| `disk_usage` | BTRFS filesystem usage and free space |
| `failed_services` | Lists failed systemd services (system + user) |
| `recent_errors` | Recent error-level journal entries |
| `system_status` | Uptime, memory, CPU temp, battery |
| `snapshot_list` | Btrfs snapshots from snapper (root + home) |
| `network_status` | NetworkManager status and connections |
| `nix_store_size` | Store free space, generation count, `nh-clean` timer state (pass `exact=true` for a precise `du` size) |
| `scrub_status` | Last btrfs scrub result |
| `hypr_config_check` | Parse a trial config line with `Hyprland --verify-config` (hyprlang or Lua; mutates nothing) |
| `hypr_config_errors` | `hyprctl configerrors` (optionally after reload) — empty = green |
| `quickshell_check` | Load-check repo bar QML against deployed Theme.qml (briefly restarts the bar) |
| `spotlight` | Point at a window or rectangle on screen (see *Spotlight* below): window by class/address, or a monitor-relative rectangle; a window miss lists the visible windows |
| `spotlight_clear` | Dismiss the current spotlight |
| `pick_target` | Ask the user to point at something (see *Point at it* below): a pill with the prompt on every monitor, `Super+Shift+P` freezes the monitor they are on, a click or drag returns the window identity and geometry |

**When to use:** Investigating build failures, system issues, disk space, or any diagnostic question. **Proactive:** If the user mentions a build error or system issue, check `failed_services` and `recent_errors` before guessing at the cause. The three `hypr_*`/`quickshell_*` tools run the CLAUDE.md "validate against the running binary" workflow — use them before rebuilding any Hyprland/QML change (session-only; they degrade gracefully in headless lanes).

Note: MCP servers are registered in the repo's tracked `.mcp.json` (project scope). The old `~/.claude/.mcp.json` seed was dead config — Claude Code never reads that path (discovered 2026-07-12; both servers had been silently unregistered). The old `niri` MCP server was retired when the Niri compositor was dropped (2026-06); GNOME itself was removed 2026-07.

## Agents

Specialized subagents available via the Task tool. Each has restricted tool access matching its role.

| Agent | Tools | Purpose |
|-------|-------|---------|
| `validator` | Bash, Read, Grep | Validate NixOS config (flake check, formatting) |
| `builder` | Bash, Read | Test NixOS builds before applying |
| `deployer` | Bash, Read, AskUserQuestion | Full deployment workflow to NixOS machines |
| `module-creator` | Write, Read, Edit, Grep | Scaffold new NixOS modules following conventions |
| `doc-generator` | Read, Edit, Write, Grep, Glob | Keep documentation in sync with code changes |

## Skills (Slash Commands)

| Skill | Description |
|-------|-------------|
| `/deploy` | Full pipeline: stage → validate → build → apply. Dispatches validator and builder agents. |
| `/add-module <category>/<name>` | Scaffold a new module at `modules/<category>/<name>.nix`, wire into imports, validate build. |

## Hooks

Repo-tracked Claude Code hooks (`.claude/settings.json` + `.claude/hooks/`) — these run automatically in every Claude Code session in this repo:

| Hook | Trigger | What it does |
|------|---------|-------------|
| `session-start.sh` | SessionStart | Injects OS awareness: hostname, booted generation, any failed system/user units |
| `post-edit-check.sh` | PostToolUse (Edit\|Write) | Auto-formats touched `.nix` files with nixfmt and runs `nix-instantiate --parse`; parse errors are fed straight back into the agent's context |
| `pre-commit-gate.sh` | PreToolUse (Bash) | Denies `git commit` when staged `.nix` changes fail `nix flake check --no-build` — "never commit untested NixOS changes", enforced |

## Desktop Integration

These scripts run outside Claude Code — they're actions in the registry `lib/keybindings.nix`, which generates the Hyprland binds (`home/hyprland.nix`), the `claudeos` help rows and the summon's list. **One key, `Super+Space`, opens the summon** (`home/quickshell/Summon.qml`): it launches apps (it replaced fuzzel, 2026-11) and runs every action below. Only three actions keep a direct key — `Super+C`, `Super+Shift+C`, `Super+Shift+P`; the rest are `Super+Space`, then the word in the first column. Claude Code cannot invoke them directly, but understanding them helps explain user context.

| Key / summon word | Script | What it does |
|------------|--------|-------------|
| `Super+Space` | summon → `claudeos-intent` | One surface for apps and actions (`home/quickshell/Summon.qml`). Opened empty it lists the Claude actions, most useful first; typing filters actions and apps together into one ranked list (app icons; conservative word-boundary ranking), with the deterministic routes as rows of their own, so the predicted route is visible before Enter. Up/Down, Tab or Ctrl+N/P move the selection; Enter runs it; Esc dismisses. Zero model calls for apps, actions and routes: `$cmd` opens a terminal, a `question?` answers as a notification, `save as <name>` / `resume <name>` snapshot and reassemble a **task context** (below). Anything else hands to the haiku router (`claudeos-intent`), which picks **wish** (→ `claude-wish`, a `wish/*` PR) vs **task** (→ the task lane: one scoped Sonnet call producing a reviewable artifact under `~/.local/state/claudeos/tasks/`, never a sent message or pushed commit — rung 1); unroutable input fails open into an interactive Claude with the text preloaded. Actions that capture the screen close the summon and wait out its fade first |
| `Super+C` | `claude-quick` | Opens a Claude Code session in Claude Desktop |
| summon: `ask` | `claude-ask-desktop` | The summon's input becomes the question (or type a `question?` straight in) → Claude answer → desktop notification. With no argument the script still opens its own zenity prompt |
| summon: `screenshot` | `claude-screenshot` | grim capture → Claude analysis (Haiku) → notification |
| summon: `screenshot terminal` | `claude-screenshot-interactive` | Screenshot → Claude analysis (Sonnet) → terminal for follow-up |
| summon: `wish` | `claude-wish` | Wish lane: plain-language wish → agent writes the Nix, validates both hosts, opens a `wish/*` PR (rung 1: propose-only). Bar island shows "✨ wishing" while it runs. Every wish card carries **Reply**: it reopens this prompt aimed at the latest wish, and `claude-wish --reply` resumes that wish's own agent session in its own worktree (kept until the PR merges or closes), so a revision lands on the same PR. The agent can also stop with a question (`WISH-NOTE`) for you to answer the same way |
| _(summon)_ | `claudeos-context` | **Task contexts** (Phase 3): named, durable, git-tracked working contexts. `save as <name>` snapshots the active workspace — window classes + a durable relaunch argv per app, and the cwds of shells in terminals — to a manifest (`~/.local/state/claudeos/contexts/<slug>.json`, its own auto-committing git repo). `resume <name>` switches to a workspace named after the slug and reassembles the windows into it, idempotently (already-present apps/cwds are skipped; it never closes a window). The bar no longer shows the active context (the island speaks only for the time and Claude), though it is still where the Shelf files new items; lanes can *prepare* a context via `claudeos_context_emit`. Restores tools and places, not pixel-perfect app state |
| summon: `clipboard` | `claude-clip` | Semantic clipboard: transform clipboard content (fix grammar, condense, to shell command, to table, summarize, translate, free-form) and copy the result back — paste anywhere |
| summon: `grab` | `claude-grab-text` | Grab Text: drag a region of the screen; any text inside (images, videos, unselectable dialogs) lands in the clipboard |
| `Super+Shift+C` | `claudeos-circle-ask` | Circle to ask: the Print region selector (`RegionShot.qml`) in circle mode. Drag a box (or click a window), type a question (Return on an empty line means "explain this"), and Claude's answer appears in a card beside the box (pending dots while it works, a short readable error if the CLI fails, is signed out, or exceeds 120 s). Esc or a click dismisses; Copy puts the answer in the clipboard. **The selected region and your question are sent to Claude**, with what the selector knows about the box (monitor, bar pill, class and title of the windows under it) and a short block of live state the script collects itself (open PRs, failed units, Claude session titles). One `claude -p --model sonnet` call on the subscription; its only tools are Read/Grep/Glob, over the crop and this repo, so it can explain ClaudeOS's own UI (why a bar badge is showing) and runs no commands. Text in the image is treated as content, never instructions. Expect about 20 s for a question about the system. The crop lives in a 0700 dir under `$XDG_RUNTIME_DIR` and is deleted when the call ends or the card is dismissed. While the card is up the layer takes keyboard focus on demand, so click it once before Esc |
| `Super+Shift+P` | — (`quickshell:pick`) | Point at it: only meaningful while an agent is waiting on `pick_target` / `claudeos-pick` (the prompt pill is up). Freezes the monitor you are on and opens the selector in pick mode; click a window or drag a box, Esc cancels. Nothing is captured. Does nothing when no pick is armed |

## Cards (Generated Surfaces)

Ephemeral, schema-validated DATA surfaces rendered deterministically by the bar
(`home/quickshell/Card*.qml`) — Phase 4 of the AI-native HMI plan. A card is a
JSON file in `$XDG_RUNTIME_DIR/claudeos-cards.d/` (tmpfs — dies on reboot)
matching `home/quickshell/cards/card.schema.json`; the writer
(`claudeos_card` / `claudeos_lane_card` in `lib/claude-script.nix`) validates
with check-jsonschema before install, so the bar only ever renders known-good
data. An invalid card degrades to a plain notification carrying the reason.
Card `run` actions resolve only through the closed registry in
`lib/card-actions.nix` — there is no free-form exec. CLI:
`claudeos-card {add <file> [id]|rm <id>|clear|list}`.

Doctrine (locked 2026-07-20): cards are **receipts first** — durable records of
finished lane work. Ambient/live-state cards (a Jasper insight, a health gauge)
are case-by-case exceptions that need their own design pass, so the surface
never drifts into a feed. Notifications stay alongside as the immediate ping;
the card is what survives it after the banner vanishes or the blocking wait
times out. Declined/negative outcomes still card, at `low` urgency — a declined
wish whose notification expired unseen must not be lost. Each lane re-emits
under a stable id, so it replaces its previous card instead of stacking, and
the tmpfs dir means cards die on reboot by construction (no `expires` field in
the schema — deliberate).

| Producer | Card | When |
|----------|------|------|
| Morning desk | Today's brief at a glance (kv + link + `open-desk` run action) | 05:30 daily, with the dashboard build |
| Wish lane | Wish granted / revised (PR link), declined, a question from the agent, stalled — each with a **Reply** button (`run wish-reply`), id `wish` | When a wish run ends |
| Task lane | Task ready (artifact link) / declined (reason), id `task` | When an intent-line task ends |
| Self-heal | Fix proposed — heal PR link, id `self-heal-<unit>` (per-unit) | When a heal agent proposes a fix |
| Auto-update | Flake updated / applied / build failed / VM-gate blocked, id `auto-update` | Sat 3 AM weekly, at each terminal state |

## Spotlight (Claude Points)

Show the user *where* something is instead of describing it. The bar's
Spotlight overlay (`home/quickshell/Spotlight.qml`) dims every monitor except
the target, rings it with a breathing accent ring, and puts a short callout
beside it (right, else left, below, above; always kept on screen and clear of
the bar). It never traps the user: it takes no keyboard focus, clicks pass
through to the apps underneath (the input mask is the callout bubble alone;
clicking the callout dismisses), and it always times out (8 s default, 60 s
cap). A new call replaces the current spotlight. CLI: `claudeos-spotlight`
(`modules/apps/spotlight.nix`).

| Command | What it does |
|---------|-------------|
| `claudeos-spotlight rect X Y W H ["text"] [--for SECONDS]` | Spotlight a rectangle in Hyprland global layout px (the `at`/`size` space of `hyprctl clients -j`) |
| `claudeos-spotlight window ADDRESS\|CLASS ["text"] [--for SECONDS]` | Spotlight a window: address (`0x…`), else exact class/initialClass, else class substring; visible workspaces only, most recently focused wins. Prints the resolved `x y w h`; exits 1 if nothing visible matches |
| `claudeos-spotlight clear` | Dismiss now |

Raw IPC (what the CLI calls; `ms` 0 = default): `qs ipc call spotlight rect X Y W H TEXT MS`,
`qs ipc call spotlight window QUERY TEXT MS` (resolves in the bar; a miss only logs),
`qs ipc call spotlight clear`.

**From an agent, use the `system-health` MCP tools `spotlight` / `spotlight_clear`
rather than the CLI.** The tool takes rectangle coordinates relative to a
monitor (what a screenshot of it shows) and adds the monitor origin itself —
the laptop panel is not at 0,0 in the global layout once a second monitor has
been arranged, so a hand-written global `rect` can land entirely off screen.

**When to point:** when the user asks where something is on screen, or
cannot find a thing an answer told them to look at or click. Not for every
mention of a window — dimming the screen is an interruption and has to earn
it (PHILOSOPHY.md, proactivity doctrine).


## Point at it (the user points for Claude)

The inverse of Spotlight: when an agent needs to know *which* window or
region the user means, it asks them to show it. `pick_target` (or the CLI
`claudeos-pick`, `modules/apps/pick.nix`) runs in two phases so the user can
get to the right window first — the question usually arrives while they are
looking at Claude, not at the thing:

1. **Armed.** Nothing is frozen. A small pill at the bottom of every monitor
   shows "Claude asks: *prompt*" with the shortcut and a Cancel button. It is
   click-through except for the pill itself and takes no keyboard focus, so
   the desktop stays live while the user switches to what Claude means.
2. **Picking.** `Super+Shift+P` (`quickshell:pick`, `lib/keybindings.nix`),
   or a click on the pill, freezes the monitor the user is on at that moment
   and opens the Print/circle selector (`home/quickshell/RegionShot.qml`) in
   pick mode with the prompt in its hint; the first click takes the window
   under the pointer, a drag takes a box, Esc cancels. Nothing is captured —
   the answer is identity and geometry only.

Quickshell IPC is synchronous, so the bar cannot reply after the user has
acted: `qs ipc call regionshot pick TOKEN PROMPT` arms and returns at once,
and the bar later renames `$XDG_RUNTIME_DIR/claudeos-pick/TOKEN.json` into
place, which the CLI waits on (inotify; `--timeout` default 300 s, after which
it tells the bar to withdraw with `qs ipc call regionshot cancel TOKEN`). A
newer pick supersedes an older one, which is reported as cancelled.

| Exit | Meaning | stdout |
|------|---------|--------|
| 0 | picked | `{"cancelled":false,"monitor","scale","x","y","width","height","global":{…},"window":{address,class,initialClass,title,pid,workspace,floating}}` — `x`/`y` monitor-relative logical px, `global` in Hyprland layout space; `window` is `null` for a box that is not exactly one window |
| 1 | the user cancelled (Esc, or Cancel on the pill) | `{"cancelled":true}` |
| 2 | timed out, or no bar | — |

**From an agent, use the `system-health` MCP tool `pick_target`** (`prompt`,
`seconds`, default 300, max 900). It blocks until the user acts, so write the
prompt as the thing you need ("the terminal you want pinned") and call it
once; a cancel means stop and ask, not retry. Pairs with `spotlight`: the
address it returns is a valid `window` target.

## Shell Commands

Fish shell functions available in any terminal. Defined in `home/shell/fish.nix` (`claudeos` lives in `home/claudeos-help.nix`).

| Command | What it does |
|---------|-------------|
| `ask "..."` | Send a question to Claude (Haiku), get answer inline |
| `fix` | Sends last failed command to Claude, suggests corrected version with confirmation |
| `explain` | Explain last command, or pipe output to understand it |
| `rebuild` | Haiku names the generation (`generation-label`) → snapper pre snapshots → `nh os switch` → post snapshots → Claude-generated commit → push |
| `approve` | Resume the last background agent session (self-heal, journal diary) and authorize its proposed action |
| `today` | Open the morning desk dashboard in Chrome app mode (`today --refresh` rebuilds it first) |
| `usage` | Claude subscription limits (session/weekly percent + reset times) — terminal twin of the bar's fuel-gauge ring (`home/quickshell/ClaudeWidget.qml`) |
| `wish "..."` | The wish lane from the terminal — same agent the summon's Wish row runs; wish in, `wish/*` PR out. `wish --reply "..."` continues the latest wish |
| `why "..."` | Natural-language diagnostics — an agent investigates the running system (system-health MCP, journals, units) and answers with cited evidence |
| `wherewasi` | "Where was I?" from structured state only (windows, repo status, recent commands) — the no-surveillance answer to Copilot Recall |
| `claudeos` | Show the capability quick reference |

## Background Services

| Service | Schedule | What it does |
|---------|----------|-------------|
| **Health monitor** | Every 15 min | Checks for failed services, high disk usage, low memory, OOM kills, critical journal entries. Sends alert context to Claude (Sonnet) for a human-readable notification if issues found. Rate-limited to one Claude call per 30 min. |
| **Journal diary** | 4 AM nightly | Haiku triages 24h of error-level journal entries against the `docs/known-issues.md` ledger. Known/benign noise is silenced; new actionable findings feed the morning brief and dashboard. |
| **Morning desk** | 05:30 daily | Agent builds `~/Desk/today/index.html` — a self-contained, Stylix-themed HTML dashboard (calendar via gcalcli, weather, diary findings, system/repo state, attention-first hierarchy). Auto-opens in Chrome app mode at first login; archives to `~/Desk/archive/`. One-time calendar bootstrap: `gcalcli init` with the Google OAuth client in sops. |
| **Daily brief** | 9 AM daily | Gathers system stats (uptime, disk, generations, flake age, git status, diary findings), sends to Claude (Sonnet) for a concise briefing. Displayed in the first terminal of the day — deliberately the only first-shell output (the macchina system fetch was dropped; no spec-sheet feed above the brief). |
| **Self-heal** | On unit failure | `claude-heal@.service` OnFailure template (`modules/common/self-heal.nix`). When a watched unit fails, a headless agent reads its journal, and if the failure is config-rooted, fixes it on a `heal/*` branch, validates with a dry-run build, and opens a PR. Never touches main; per-unit 6h cooldown. `approve` resumes the session. |
| **Auto-update** | Sat 3 AM weekly | `nix flake update` → test build → Claude-reviewed changelog → haiku-named generation slug → commit and push. Reverts flake.lock on build failure. |
| **Jasper** | Every 30 min (waking hours) | Personal-companion lane (`modules/apps/jasper.nix`) — dumb collectors (wttr.in, gcalcli) + a bash significance gate + ONE `claude -p` sonnet call for a warm, ownership-aware insight. Rides the Claude subscription (no dedicated API key); writes `jasper-insight.txt`; the insight (emoji + sentence) lives at the top of the calendar popup that opens from the bar's center island (`home/quickshell/Jasper.qml` singleton), and a fresh one is announced once as a toast note. Jasper no longer appears on the island itself, which speaks only for the time and for Claude. Interactive Claude sessions show as a "✳ N" busy count beside the clock and list by app title in the popup (`Sessions.qml`, read from `~/.claude/sessions/*.json`); only one busy longer than 90 s is promoted to the agent face, and a turn that ends after 20 s+ of work flashes a "done" face (check + title) for ~4 s. The rest of the bar's old island faces moved: now-playing is a small spectrum in the right pill (click for the media popup), volume/brightness keys widen the volume widget briefly, notification peeks are short-lived toasts, and the Shelf opens from its hotkey only (no drag-to-shelve on the bar). |

## Proactive Behaviors

Guidelines for when Claude should suggest or use capabilities without being asked:

- **Build errors:** Check `system-health` → `failed_services` and `recent_errors` before guessing at causes
- **Disk space concerns:** Use `system-health` → `disk_usage` and `nix_store_size` to give concrete numbers
- **After config changes:** Suggest `/deploy` or remind about the validate → build → apply workflow
- **Module creation:** If user wants to add a new service/app, suggest `/add-module` to scaffold correctly
- **NixOS option lookup:** Use `nixos` MCP to verify options exist before adding them to config
- **Recurring journal noise:** If an error is benign, record it in `docs/known-issues.md` so the journal diary stops resurfacing it
