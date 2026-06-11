# ClaudeOS Capabilities

ClaudeOS is a Claude-native NixOS system where Claude is integrated at every layer: desktop keybindings, shell commands, MCP servers, Claude Code agents/skills, and background monitoring. This document is the single reference for what's available and when to use it.

Run `claudeos` in a terminal to see the user-facing quick reference.

## MCP Servers

### nixos (`mcp-nixos`)

Search NixOS options, packages, and home-manager options from within Claude Code.

**When to use:** User asks about a NixOS option, needs to find a package name, or wants to check available module options before adding them to the config.

### system-health (`mcp-system-health`)

Direct access to system diagnostics — 8 tools covering disk, services, journal, memory, snapshots, network, Nix store, and btrfs scrub status.

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

**When to use:** Investigating build failures, system issues, disk space, or any diagnostic question. **Proactive:** If the user mentions a build error or system issue, check `failed_services` and `recent_errors` before guessing at the cause.

### niri (`mcp-niri`)

Control the Niri Wayland compositor — manage windows, workspaces, and take screenshots.

| Tool | Purpose |
|------|---------|
| `list_windows` | All open windows with IDs, titles, app IDs |
| `list_workspaces` | All workspaces with indices and active status |
| `focused_window` | Details about the currently focused window |
| `focused_output` | Details about the currently focused monitor |
| `focus_window` | Focus a specific window by ID |
| `close_window` | Close the currently focused window |
| `move_to_workspace` | Move focused column to a target workspace |
| `set_column_width` | Set column width (absolute or relative) |
| `focus_workspace` | Switch to a workspace by number |
| `toggle_fullscreen` | Toggle fullscreen on focused window |
| `screenshot_screen` | Take a screenshot of the entire screen |

**When to use:** User wants to manage windows, check what's open, organize workspaces, or needs a screenshot for context.

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

## Desktop Integration

These scripts run outside Claude Code — they're keybindings in the Niri compositor that invoke Claude via the CLI. Claude Code cannot invoke them directly, but understanding them helps explain user context.

| Keybinding | Script | What it does |
|------------|--------|-------------|
| `Mod+C` | `claude-quick` | Opens Claude Code in a floating Ghostty terminal |
| `Mod+A` | `claude-ask-desktop` | Fuzzel popup prompt → Claude answer → desktop notification |
| `Mod+Shift+A` | `claude-screenshot` | Screenshot → Claude analysis (Haiku) → notification |
| `Mod+Ctrl+A` | `claude-screenshot-interactive` | Screenshot → Claude analysis (Sonnet) → terminal for follow-up |
| `Ctrl+Alt+Space` | `claude-desktop` | Opens Claude Desktop (Electron app with file/image support) |

## Shell Commands

Fish shell functions available in any terminal. Defined in `home/shell/fish.nix` (`claudeos` lives in `home/claudeos-help.nix`).

| Command | What it does |
|---------|-------------|
| `ask "..."` | Send a question to Claude (Haiku), get answer inline |
| `fix` | Sends last failed command to Claude, suggests corrected version with confirmation |
| `explain` | Explain last command, or pipe output to understand it |
| `rebuild` | Btrfs snapshots → `nixos-rebuild switch` → Claude-generated commit → push |
| `claudeos` | Show the capability quick reference |

## Background Services

| Service | Schedule | What it does |
|---------|----------|-------------|
| **Health monitor** | Every 15 min | Checks for failed services, high disk usage, low memory, OOM kills, critical journal entries. Sends alert context to Claude (Sonnet) for a human-readable notification if issues found. Rate-limited to one Claude call per 30 min. |
| **Daily brief** | 9 AM daily | Gathers system stats (uptime, disk, generations, flake age, git status), sends to Claude (Sonnet) for a concise briefing. Displayed in first terminal of the day alongside macchina system fetch. |
| **Jasper** | Always running | AI companion daemon (systemd user service, `modules/apps/jasper.nix`). Has its own Anthropic API key, Google integrations for weather/calendar/routes. Surfaces in the Noctalia bar via the `jasper-insights` plugin widget (`home/niri.nix`). |

## Proactive Behaviors

Guidelines for when Claude should suggest or use capabilities without being asked:

- **Build errors:** Check `system-health` → `failed_services` and `recent_errors` before guessing at causes
- **Disk space concerns:** Use `system-health` → `disk_usage` and `nix_store_size` to give concrete numbers
- **Window management:** If user mentions wanting to arrange windows or check what's open, use `niri` MCP
- **After config changes:** Suggest `/deploy` or remind about the validate → build → apply workflow
- **Module creation:** If user wants to add a new service/app, suggest `/add-module` to scaffold correctly
- **NixOS option lookup:** Use `nixos` MCP to verify options exist before adding them to config
