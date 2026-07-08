# ClaudeOS Phase 4: Deep Claude Integration

**Date:** 2026-02-14
**Status:** Approved

## Overview

Five features that deepen Claude's integration into ClaudeOS, spanning declarative AI configuration, filesystem safety, conversational system management, desktop UX, and notification feedback loops.

## Features

### 1. Declarative Claude Code Configuration

**Problem:** Claude Code's config (`~/.claude/settings.json`, `~/.claude/.mcp.json`) is mutable state outside Nix's control — a gap in an otherwise fully declarative system.

**Solution:** A home-manager module (`home/claude-code.nix`) that generates Claude Code configuration files from Nix expressions.

**Files managed:**
- `~/.claude/settings.json` — global settings, hooks (including notification hook from feature 5)
- `~/.claude/.mcp.json` — MCP server definitions (including system health server from feature 3)

**Files NOT managed (per-project):**
- `.claude/settings.local.json` — project-specific permissions
- `.claude/agents/*.md` — project-specific agents
- `CLAUDE.md` — project instructions

**Implementation:**
- `home.file.".claude/settings.json"` with `builtins.toJSON`
- `home.file.".claude/.mcp.json"` with `builtins.toJSON`
- GitHub token export stays in `fish.nix` (runtime value from `gh auth token`)

### 2. Pre-Rebuild Snapshots with Snapper

**Problem:** NixOS generations protect system configuration but not user data or runtime state. A bad rebuild can affect `/home` or service data with no recovery path.

**Solution:** Snapper for btrfs snapshot management — both scheduled timeline snapshots and on-demand pre/post rebuild pairs.

**Module:** `modules/common/snapshots.nix`

**Configuration:**
- `root` config: snapshots of `/`, timeline-based (10 hourly, 7 daily, 2 weekly), automatic cleanup
- `home` config: snapshots of `/home`, `ALLOW_USERS = [ user ]`, timeline-based (10 hourly, 7 daily), automatic cleanup
- No snapshots of `/nix` (reproducible via rebuild) or `/var/log` (rarely needs rollback)

**Fish integration:** The `rebuild` alias becomes a function that:
1. Creates snapper pre-snapshot (root + home)
2. Runs `nixos-rebuild switch`
3. Creates snapper post-snapshot
4. Prints snapshot numbers for potential `undochange`

**Rollback:** `snapper -c root undochange <pre>..<post>` reverts filesystem changes between snapshots.

### 3. System Health MCP Server

**Problem:** Claude Code has NixOS reference knowledge (via mcp-nixos) but no visibility into the actual running system's state.

**Solution:** A stdio-based MCP server that exposes system health tools to Claude Code.

**Tools exposed:**

| Tool | Implementation |
|------|---------------|
| `disk_usage` | `btrfs fi usage /` + `df -h` |
| `failed_services` | `systemctl --failed` |
| `recent_errors` | `journalctl -p err -n 50 --no-pager` |
| `system_status` | uptime, load, memory, swap, CPU temp, battery |
| `snapshot_list` | `snapper list` for root and home configs |
| `network_status` | NetworkManager state, connections, IPs |
| `nix_store_size` | `/nix/store` size, last GC run |
| `scrub_status` | last btrfs scrub result |

**Implementation:** Python script installed via `modules/apps/mcp-system-health.nix`. Registered in the declarative `.mcp.json` from feature 1.

### 4. COSMIC Keybinding for Claude Quick-Action

**Problem:** Launching Claude Code requires opening a terminal, navigating, running `claude`. Multiple steps break flow.

**Solution:** `Super+C` opens a floating Ghostty window running Claude Code — one keystroke to AI from anywhere on the desktop.

**Implementation:**
- Launcher script: `ghostty --class=claude-quick -e claude` (with window size flags)
- COSMIC keybinding registered via home-manager config file generation
- `claude-quick` window class available for COSMIC window rules (floating, centered)
- Inherits Stylix theme automatically

### 5. Desktop Notifications from Claude Agents

**Problem:** Claude Code runs in terminals that may be minimized or on other workspaces. No feedback loop when tasks complete.

**Solution:** Claude Code `Notification` hook that pipes events to COSMIC's native notification system via `notify-send`.

**Implementation:** Hook configured in the declarative `settings.json` from feature 1:
```json
{
  "hooks": {
    "Notification": [{
      "type": "command",
      "command": "notify-send --app-name='Claude Code' --icon=claude-logo ..."
    }]
  }
}
```

- Uses `notify-send` (libnotify) for simplicity
- Claude logo as notification icon
- Fires on: task completion, user input needed, errors

## Feature Dependencies

```
Feature 1 (Declarative Config) ─── Feature 3 registers MCP server here
                                └── Feature 5 hooks live here
Feature 2 (Snapper) ─────────────── Feature 3 exposes snapshot_list tool
Feature 4 (Keybinding) ──────────── Independent
```

Build order: 1 → 2 → 3 → 5 → 4 (4 is independent, can be done anytime)

## New Files

| File | Purpose |
|------|---------|
| `home/claude-code.nix` | Declarative Claude Code settings + MCP + hooks |
| `modules/common/snapshots.nix` | Snapper configuration |
| `modules/apps/mcp-system-health.nix` | System health MCP server module |
| `modules/apps/mcp-system-health.py` | MCP server implementation script |
| Launcher script (in system packages) | Claude quick-action launcher |

## Modified Files

| File | Change |
|------|--------|
| `home/default.nix` | Import `claude-code.nix` |
| `modules/common/default.nix` | Import `snapshots.nix` |
| `modules/apps/default.nix` | Import `mcp-system-health.nix` |
| `home/shell/fish.nix` | Update `rebuild` alias to use snapper pre/post |

## Design Decisions

1. **Snapper over btrbk** — snapper's pre/post pairs and native `undochange` are purpose-built for the pre-rebuild use case. btrbk can be added later for remote backups.
2. **Python for MCP server** — clean JSON output, good stdlib for system commands, easier to maintain than bash.
3. **`notify-send` over D-Bus direct** — simpler, portable, libnotify already available.
4. **home.file over xdg.configFile** — Claude Code uses `~/.claude/` not `~/.config/claude/`.
5. **No snapshots of /nix or /var/log** — /nix is reproducible, logs rarely need rollback.
