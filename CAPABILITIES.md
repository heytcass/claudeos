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
| `nix_store_size` | Nix store disk usage and GC timer |
| `scrub_status` | Last btrfs scrub result |
| `hypr_config_check` | Trial a hyprland.conf field/value against the running compositor, then restore |
| `hypr_config_errors` | `hyprctl configerrors` (optionally after reload) — empty = green |
| `quickshell_check` | Load-check repo bar QML against deployed Theme.qml (briefly restarts the bar) |

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

These scripts run outside Claude Code — they're Hyprland keybindings (generated from `lib/keybindings.nix` in `home/hyprland.nix`) that invoke Claude via the CLI. Claude Code cannot invoke them directly, but understanding them helps explain user context.

| Keybinding | Script | What it does |
|------------|--------|-------------|
| `Super+C` | `claude-quick` | Opens Claude Code in a Ghostty terminal |
| `Super+A` | `claude-ask-desktop` | Zenity popup prompt → Claude answer → desktop notification |
| `Super+Shift+A` | `claude-screenshot` | grim capture → Claude analysis (Haiku) → notification |
| `Super+Ctrl+A` | `claude-screenshot-interactive` | Screenshot → Claude analysis (Sonnet) → terminal for follow-up |
| `Super+W` | `claude-wish` | Wish lane: plain-language wish → agent writes the Nix, validates both hosts, opens a `wish/*` PR (rung 1: propose-only). Bar island shows "✨ wishing" while it runs; `approve` resumes the session |
| `Super+Shift+V` | `claude-clip` | Semantic clipboard: transform clipboard content (fix grammar, condense, to shell command, to table, summarize, translate, free-form) and copy the result back — paste anywhere |
| `Super+T` | `claude-grab-text` | Grab Text: drag a region of the screen; any text inside (images, videos, unselectable dialogs) lands in the clipboard |

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
| `usage` | Claude subscription limits (session/weekly percent + reset times) — terminal twin of the bar's fuel-gauge ring (`home/quickshell/ClaudeUsageWidget.qml`) |
| `wish "..."` | The wish lane from the terminal — same agent Super+W runs; wish in, `wish/*` PR out |
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
| **Jasper** | Every 30 min (waking hours) | Personal-companion lane (`modules/apps/jasper.nix`) — dumb collectors (wttr.in, gcalcli) + a bash significance gate + ONE `claude -p` sonnet call for a warm, ownership-aware insight. Rides the Claude subscription (no dedicated API key); writes `jasper-insight.txt`; the mood emoji lives beside the clock in the bar's center island, the sentence at the top of its calendar popup (`home/quickshell/Jasper.qml` singleton). |

## Proactive Behaviors

Guidelines for when Claude should suggest or use capabilities without being asked:

- **Build errors:** Check `system-health` → `failed_services` and `recent_errors` before guessing at causes
- **Disk space concerns:** Use `system-health` → `disk_usage` and `nix_store_size` to give concrete numbers
- **After config changes:** Suggest `/deploy` or remind about the validate → build → apply workflow
- **Module creation:** If user wants to add a new service/app, suggest `/add-module` to scaffold correctly
- **NixOS option lookup:** Use `nixos` MCP to verify options exist before adding them to config
- **Recurring journal noise:** If an error is benign, record it in `docs/known-issues.md` so the journal diary stops resurfacing it
