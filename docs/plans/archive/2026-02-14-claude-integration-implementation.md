# ClaudeOS Phase 4: Deep Claude Integration — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deeply integrate Claude into the OS across 5 features: declarative Claude Code config, snapper snapshots, system health MCP server, COSMIC keybinding, and desktop notifications.

**Architecture:** Each feature is a new NixOS or home-manager module following existing patterns. Features build on each other: declarative config (Task 1) is the foundation that hosts MCP registration (Task 3) and notification hooks (Task 5). Snapper (Task 2) and the keybinding (Task 4) are independent.

**Tech Stack:** NixOS modules (Nix), home-manager, snapper, Python 3 (MCP server), Fish shell, COSMIC desktop, libnotify

---

## Task 1: Declarative Claude Code Configuration

**Files:**
- Create: `home/claude-code.nix`
- Modify: `home/default.nix:13-21` (add import)
- Modify: `home/shell/fish.nix:107-109` (remove GH token export, move to claude-code.nix)

**Step 1: Create `home/claude-code.nix`**

This module generates `~/.claude/settings.json` and `~/.claude/.mcp.json` from Nix expressions. It also manages the statusline script.

```nix
# home/claude-code.nix
{ pkgs, config, ... }:

let
  themeLib = import ../lib/theme.nix;

  # Statusline script — reads Stylix palette for themed Claude Code status bar
  statuslineScript = pkgs.writeShellScript "claude-statusline" ''
    PALETTE="$HOME/.config/stylix/palette.json"

    color() {
        local hex
        hex=$(${pkgs.jq}/bin/jq -r ".$1" "$PALETTE" 2>/dev/null)
        if [ -n "$hex" ] && [ "$hex" != "null" ]; then
            printf '\033[38;2;%d;%d;%dm' "0x''${hex:0:2}" "0x''${hex:2:2}" "0x''${hex:4:2}"
        fi
    }

    red=$(color base08)
    orange=$(color base09)
    yellow=$(color base0A)
    green=$(color base0B)
    cyan=$(color base0C)
    blue=$(color base0D)
    purple=$(color base0E)
    white=$(color base05)
    dimmed=$(color base03)
    reset='\033[0m'

    input=$(cat)

    cwd=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.workspace.current_dir')
    model=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.model.display_name')
    used_pct=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.context_window.used_percentage // empty')
    total_input=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.context_window.total_input_tokens // 0')
    total_output=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.context_window.total_output_tokens // 0')

    dir_display=$(echo "$cwd" | sed "s|^$HOME|~|" | awk -F/ '{
        if (NF <= 3) print $0;
        else printf "%s/%s/%s", $(NF-2), $(NF-1), $NF
    }')

    git_info=""
    if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
        branch=$(git -C "$cwd" -c core.useOptionalLocks=false branch --show-current 2>/dev/null)
        if [ -n "$branch" ]; then
            git_info=" ''${orange} ''${branch}''${reset}"
            git_status=$(git -C "$cwd" -c core.useOptionalLocks=false status --porcelain 2>/dev/null)
            modified=$(echo "$git_status" | grep -c "^ M")
            staged=$(echo "$git_status" | grep -c "^[MADRC]")
            untracked=$(echo "$git_status" | grep -c "^??")
            status_info=""
            [ "$staged" -gt 0 ] && status_info="''${status_info}''${green}+''${staged}''${reset}"
            [ "$modified" -gt 0 ] && status_info="''${status_info}''${red}!''${modified}''${reset}"
            [ "$untracked" -gt 0 ] && status_info="''${status_info}''${red}?''${untracked}''${reset}"
            [ -n "$status_info" ] && git_info="''${git_info} ''${status_info}"
        fi
    fi

    model_short=$(echo "$model" | sed 's/Claude //')

    context_info=""
    if [ -n "$used_pct" ]; then
        pct=$(printf "%.0f" "$used_pct")
        if [ "$pct" -gt 75 ]; then
            context_info=" ''${red}ctx:''${pct}%%''${reset}"
        elif [ "$pct" -gt 50 ]; then
            context_info=" ''${yellow}ctx:''${pct}%%''${reset}"
        else
            context_info=" ''${cyan}ctx:''${pct}%%''${reset}"
        fi
    fi

    cost=""
    if [ "$total_input" -gt 0 ] || [ "$total_output" -gt 0 ]; then
        cost_val=$(awk "BEGIN {printf \"%.2f\", ($total_input * 3 + $total_output * 15) / 1000000}")
        cost=" ''${dimmed}\$''${cost_val}''${reset}"
    fi

    printf "''${white}''${dir_display}''${reset}''${git_info} ''${purple}''${model_short}''${reset}''${context_info}''${cost}\n"
  '';

  # Claude Code global settings
  claudeSettings = {
    statusLine = {
      type = "command";
      command = "bash ${statuslineScript}";
    };
    enabledPlugins = {
      "frontend-design@claude-plugins-official" = true;
      "github@claude-plugins-official" = true;
      "feature-dev@claude-plugins-official" = true;
      "ralph-loop@claude-plugins-official" = true;
      "superpowers@claude-plugins-official" = true;
      "security-guidance@claude-plugins-official" = true;
      "pr-review-toolkit@claude-plugins-official" = true;
      "agent-sdk-dev@claude-plugins-official" = true;
      "plugin-dev@claude-plugins-official" = true;
      "explanatory-output-style@claude-plugins-official" = true;
      "claude-md-management@claude-plugins-official" = true;
      "claude-code-setup@claude-plugins-official" = true;
      "learning-output-style@claude-plugins-official" = true;
      "rust-analyzer-lsp@claude-plugins-official" = true;
      "playground@claude-plugins-official" = true;
    };
    skipDangerousModePermissionPrompt = true;
    env = {
      CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
    };
  };

  # MCP server configuration
  mcpConfig = {
    mcpServers = {
      nixos = {
        command = "nix";
        args = [ "run" "github:utensils/mcp-nixos" "--" ];
      };
    };
  };
in
{
  # Generate ~/.claude/settings.json
  home.file.".claude/settings.json" = {
    text = builtins.toJSON claudeSettings;
    force = true;
  };

  # Generate ~/.claude/.mcp.json
  home.file.".claude/.mcp.json" = {
    text = builtins.toJSON mcpConfig;
    force = true;
  };
}
```

**Step 2: Add import to `home/default.nix`**

Add `./claude-code.nix` to the imports list (after `./macchina.nix`).

**Step 3: Remove the GitHub token export from `home/shell/fish.nix`**

Remove lines 107-109 (the `GITHUB_PERSONAL_ACCESS_TOKEN` export). Move it to `home/claude-code.nix`'s `interactiveShellInit` or keep it in fish.nix with a comment referencing claude-code.nix. Decision: keep in fish.nix — it's a shell concern, not a Claude Code config concern. Just add a cross-reference comment.

**Step 4: Remove the old statusline script**

The old `~/.claude/statusline-command.sh` was manually placed. Now it's managed by Nix (the `statuslineScript` derivation produces a store path). The `settings.json` references the store path directly. Remove the stale file after rebuild.

**Step 5: Validate**

Run: `nix flake check`
Run: `nix build .#nixosConfigurations.gti.config.system.build.toplevel --dry-run`
Run: `nix build .#nixosConfigurations.transporter.config.system.build.toplevel --dry-run`
Expected: all pass

**Step 6: Commit**

```bash
git add home/claude-code.nix
git add home/default.nix
git commit -m "feat: declarative Claude Code configuration via home-manager"
```

---

## Task 2: Snapper Btrfs Snapshots

**Files:**
- Create: `modules/common/snapshots.nix`
- Modify: `modules/common/default.nix:4-13` (add import)
- Modify: `home/shell/fish.nix:26` (update rebuild alias to use snapper)

**Step 1: Create `modules/common/snapshots.nix`**

```nix
# modules/common/snapshots.nix
{ user, ... }:

{
  # Snapper for btrfs snapshot management
  # Provides: timeline snapshots (hourly safety net) + pre/post rebuild pairs
  services.snapper = {
    snapshotInterval = "hourly";
    cleanupInterval = "1d";
    persistentTimer = true;

    configs = {
      root = {
        SUBVOLUME = "/";
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_HOURLY = 10;
        TIMELINE_LIMIT_DAILY = 7;
        TIMELINE_LIMIT_WEEKLY = 2;
        TIMELINE_LIMIT_MONTHLY = 0;
        TIMELINE_LIMIT_YEARLY = 0;
      };

      home = {
        SUBVOLUME = "/home";
        ALLOW_USERS = [ user ];
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_HOURLY = 10;
        TIMELINE_LIMIT_DAILY = 7;
        TIMELINE_LIMIT_WEEKLY = 2;
        TIMELINE_LIMIT_MONTHLY = 0;
        TIMELINE_LIMIT_YEARLY = 0;
      };
    };
  };
}
```

**Step 2: Add import to `modules/common/default.nix`**

Add `./snapshots.nix` to the imports list.

**Step 3: Update the `rebuild` alias in `home/shell/fish.nix`**

Replace the simple alias with a Fish function that wraps rebuilds with snapper pre/post snapshots:

Remove from `shellAliases`:
```nix
rebuild = "sudo nixos-rebuild switch --flake ~/.config/claudeos#(hostname)";
```

Add to `functions`:
```nix
# Rebuild NixOS with snapper pre/post snapshots for safe rollback
rebuild = ''
  set -l pre_root (sudo snapper -c root create --type pre --cleanup-algorithm number --print-number --description "pre-rebuild")
  set -l pre_home (snapper -c home create --type pre --cleanup-algorithm number --print-number --description "pre-rebuild")
  echo "Snapshots: root#$pre_root, home#$pre_home"

  sudo nixos-rebuild switch --flake ~/.config/claudeos#(hostname) $argv

  if test $status -eq 0
    sudo snapper -c root create --type post --pre-number $pre_root --cleanup-algorithm number --description "post-rebuild"
    snapper -c home create --type post --pre-number $pre_home --cleanup-algorithm number --description "post-rebuild"
    echo "Rebuild complete. Rollback: sudo snapper -c root undochange $pre_root..(math $pre_root + 1)"
  else
    echo "Rebuild failed. Pre-snapshots preserved: root#$pre_root, home#$pre_home"
  end
'';
```

Keep `rebuild-test` as a simple alias (no snapshots needed for test rebuilds).

**Step 4: Validate**

Run: `nix flake check`
Run: `nix build .#nixosConfigurations.gti.config.system.build.toplevel --dry-run`
Expected: pass

**Step 5: Commit**

```bash
git add modules/common/snapshots.nix modules/common/default.nix home/shell/fish.nix
git commit -m "feat: snapper btrfs snapshots with pre/post rebuild safety"
```

**Step 6: Apply and verify (requires live system)**

After `sudo nixos-rebuild switch`, verify:
- `sudo snapper -c root list` shows the root config
- `snapper -c home list` works without sudo (ALLOW_USERS)
- Run `rebuild` and verify pre/post snapshots are created

**Note:** Snapper requires `.snapshots` subvolumes to exist on each configured subvolume. On first rebuild, snapper may create these automatically, or they may need manual creation:
```bash
sudo btrfs subvolume create /.snapshots
sudo btrfs subvolume create /home/.snapshots
sudo chmod 750 /.snapshots /home/.snapshots
```

---

## Task 3: System Health MCP Server

**Files:**
- Create: `modules/apps/mcp-system-health/default.nix` (NixOS module)
- Create: `modules/apps/mcp-system-health/server.py` (MCP server implementation)
- Modify: `modules/apps/default.nix:4-8` (add import)
- Modify: `home/claude-code.nix` (register MCP server)

**Step 1: Create the MCP server Python script**

Create `modules/apps/mcp-system-health/server.py` — a self-contained Python script implementing the MCP stdio protocol (JSON-RPC 2.0 with Content-Length headers). No external dependencies beyond Python stdlib.

The script implements these tools:
- `disk_usage` — runs `btrfs fi usage /` and `df -h`
- `failed_services` — runs `systemctl --failed`
- `recent_errors` — runs `journalctl -p err -n 50 --no-pager`
- `system_status` — reads `/proc/uptime`, `/proc/loadavg`, `/proc/meminfo`, battery via `/sys/class/power_supply/`, CPU temp via `/sys/class/thermal/`
- `snapshot_list` — runs `snapper list` for root and home configs
- `network_status` — runs `nmcli general status` and `nmcli connection show --active`
- `nix_store_size` — runs `du -sh /nix/store` and reads GC timer status
- `scrub_status` — runs `btrfs scrub status /`

Each tool runs subprocess commands and returns the output as text content.

The MCP protocol implementation:
- Reads Content-Length framed JSON-RPC from stdin
- Writes Content-Length framed JSON-RPC to stdout
- Handles: `initialize`, `notifications/initialized`, `tools/list`, `tools/call`
- ~250 lines of Python, no deps

```python
#!/usr/bin/env python3
"""ClaudeOS System Health MCP Server — exposes system diagnostics to Claude Code."""

import json
import subprocess
import sys
from pathlib import Path


def read_message():
    """Read a JSON-RPC message with Content-Length header from stdin."""
    headers = {}
    while True:
        line = sys.stdin.readline()
        if not line or line.strip() == "":
            break
        if ":" in line:
            key, value = line.split(":", 1)
            headers[key.strip()] = value.strip()

    content_length = int(headers.get("Content-Length", 0))
    if content_length == 0:
        return None

    body = sys.stdin.read(content_length)
    return json.loads(body)


def write_message(msg):
    """Write a JSON-RPC message with Content-Length header to stdout."""
    body = json.dumps(msg)
    header = f"Content-Length: {len(body)}\r\n\r\n"
    sys.stdout.write(header)
    sys.stdout.write(body)
    sys.stdout.flush()


def run_cmd(cmd, timeout=10):
    """Run a shell command and return its output."""
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=timeout
        )
        output = result.stdout
        if result.returncode != 0 and result.stderr:
            output += f"\nSTDERR: {result.stderr}"
        return output.strip() or "(no output)"
    except subprocess.TimeoutExpired:
        return "(command timed out)"
    except Exception as e:
        return f"(error: {e})"


TOOLS = [
    {
        "name": "disk_usage",
        "description": "Show btrfs filesystem usage and disk space (btrfs fi usage + df -h)",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "failed_services",
        "description": "List any failed systemd services",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "recent_errors",
        "description": "Show recent error-level journal entries",
        "inputSchema": {
            "type": "object",
            "properties": {
                "count": {
                    "type": "integer",
                    "description": "Number of entries (default 50)",
                    "default": 50,
                }
            },
        },
    },
    {
        "name": "system_status",
        "description": "System overview: uptime, load, memory, CPU temp, battery",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "snapshot_list",
        "description": "List btrfs snapshots managed by snapper",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "network_status",
        "description": "NetworkManager status and active connections",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "nix_store_size",
        "description": "Nix store disk usage and GC status",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "scrub_status",
        "description": "Last btrfs scrub result",
        "inputSchema": {"type": "object", "properties": {}},
    },
]


def handle_tool_call(name, arguments):
    """Execute a tool and return the result."""
    if name == "disk_usage":
        btrfs = run_cmd("btrfs fi usage / 2>/dev/null || echo 'btrfs not available'")
        df = run_cmd("df -h --type=btrfs --type=vfat 2>/dev/null")
        return f"=== BTRFS USAGE ===\n{btrfs}\n\n=== DISK FREE ===\n{df}"

    elif name == "failed_services":
        return run_cmd("systemctl --failed --no-pager")

    elif name == "recent_errors":
        count = arguments.get("count", 50)
        return run_cmd(f"journalctl -p err -n {count} --no-pager")

    elif name == "system_status":
        parts = []
        parts.append("UPTIME: " + run_cmd("uptime"))
        parts.append("MEMORY:\n" + run_cmd("free -h"))

        # CPU temperature
        temp = ""
        for p in Path("/sys/class/thermal/").glob("thermal_zone*/temp"):
            try:
                t = int(p.read_text().strip()) / 1000
                zone = p.parent.name
                temp += f"  {zone}: {t:.1f}C\n"
            except Exception:
                pass
        parts.append("CPU TEMP:\n" + (temp or "  (not available)"))

        # Battery
        bat_path = Path("/sys/class/power_supply/BAT0")
        if bat_path.exists():
            try:
                capacity = (bat_path / "capacity").read_text().strip()
                status = (bat_path / "status").read_text().strip()
                parts.append(f"BATTERY: {capacity}% ({status})")
            except Exception:
                parts.append("BATTERY: (read error)")
        else:
            parts.append("BATTERY: (not present)")

        return "\n".join(parts)

    elif name == "snapshot_list":
        root = run_cmd("snapper -c root list 2>/dev/null || echo 'root config not found'")
        home = run_cmd("snapper -c home list 2>/dev/null || echo 'home config not found'")
        return f"=== ROOT SNAPSHOTS ===\n{root}\n\n=== HOME SNAPSHOTS ===\n{home}"

    elif name == "network_status":
        general = run_cmd("nmcli general status 2>/dev/null || echo 'nmcli not available'")
        active = run_cmd("nmcli connection show --active 2>/dev/null")
        return f"=== STATUS ===\n{general}\n\n=== ACTIVE CONNECTIONS ===\n{active}"

    elif name == "nix_store_size":
        size = run_cmd("du -sh /nix/store 2>/dev/null | cut -f1")
        gc = run_cmd("systemctl status nix-gc.timer --no-pager 2>/dev/null | head -5")
        return f"NIX STORE SIZE: {size}\n\n=== GC TIMER ===\n{gc}"

    elif name == "scrub_status":
        return run_cmd("btrfs scrub status / 2>/dev/null || echo 'scrub status not available'")

    else:
        return f"Unknown tool: {name}"


def main():
    """Main MCP server loop."""
    while True:
        msg = read_message()
        if msg is None:
            break

        method = msg.get("method", "")
        msg_id = msg.get("id")

        if method == "initialize":
            write_message(
                {
                    "jsonrpc": "2.0",
                    "id": msg_id,
                    "result": {
                        "protocolVersion": "2024-11-05",
                        "capabilities": {"tools": {}},
                        "serverInfo": {
                            "name": "claudeos-system-health",
                            "version": "1.0.0",
                        },
                    },
                }
            )

        elif method == "notifications/initialized":
            pass  # No response needed for notifications

        elif method == "tools/list":
            write_message(
                {"jsonrpc": "2.0", "id": msg_id, "result": {"tools": TOOLS}}
            )

        elif method == "tools/call":
            params = msg.get("params", {})
            tool_name = params.get("name", "")
            arguments = params.get("arguments", {})
            result_text = handle_tool_call(tool_name, arguments)
            write_message(
                {
                    "jsonrpc": "2.0",
                    "id": msg_id,
                    "result": {
                        "content": [{"type": "text", "text": result_text}]
                    },
                }
            )

        elif msg_id is not None:
            write_message(
                {
                    "jsonrpc": "2.0",
                    "id": msg_id,
                    "error": {
                        "code": -32601,
                        "message": f"Method not found: {method}",
                    },
                }
            )


if __name__ == "__main__":
    main()
```

**Step 2: Create the NixOS module `modules/apps/mcp-system-health/default.nix`**

```nix
# modules/apps/mcp-system-health/default.nix
{ pkgs, ... }:

let
  mcpServer = pkgs.writeScriptBin "mcp-system-health" ''
    #!${pkgs.python3}/bin/python3
    ${builtins.readFile ./server.py}
  '';
in
{
  environment.systemPackages = [ mcpServer ];
}
```

**Step 3: Add import to `modules/apps/default.nix`**

Add `./mcp-system-health` to the imports list.

**Step 4: Register in `home/claude-code.nix` MCP config**

Add to the `mcpConfig.mcpServers` attrset:

```nix
system-health = {
  command = "mcp-system-health";
  args = [];
};
```

**Step 5: Validate**

Run: `nix flake check`
Run: `nix build .#nixosConfigurations.gti.config.system.build.toplevel --dry-run`
Expected: pass

**Step 6: Commit**

```bash
git add modules/apps/mcp-system-health/
git add modules/apps/default.nix home/claude-code.nix
git commit -m "feat: system health MCP server for Claude Code"
```

**Step 7: Test the MCP server (after rebuild)**

Run manually to verify it responds to the MCP protocol:
```bash
echo 'Content-Length: 53\r\n\r\n{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | mcp-system-health
```
Expected: JSON response listing 8 tools.

Then verify Claude Code picks it up by asking "How's my system looking?" in a Claude Code session.

---

## Task 4: COSMIC Keybinding for Claude Quick-Action

**Files:**
- Modify: `modules/common/system.nix` (add launcher script to system packages)
- Research: COSMIC keybinding config format at `~/.config/cosmic/com.system76.CosmicComp/v1/`

**Step 1: Create the launcher script**

Add to `modules/common/system.nix` systemPackages (or create a separate module if preferred):

```nix
(pkgs.writeShellScriptBin "claude-quick" ''
  exec ${pkgs.ghostty}/bin/ghostty \
    --class=claude-quick \
    --initial-window-width=960 \
    --initial-window-height=560 \
    -e claude
'')
```

Note: Ghostty is installed via home-manager, so the package reference may need adjustment. Check if `pkgs.ghostty` resolves or if a different reference is needed.

**Step 2: Research COSMIC keybinding format**

Before implementing, check the actual COSMIC keybinding config structure:
```bash
ls ~/.config/cosmic/com.system76.CosmicComp/v1/
cat ~/.config/cosmic/com.system76.CosmicComp/v1/key_bindings
```

COSMIC keybindings may be stored in RON format. Check if `cosmic-ext-ctl` can set keybindings:
```bash
cosmic-ext-ctl --help
```

**Step 3: Configure the keybinding**

Based on research, either:
- Generate the keybinding config via home-manager file (like `cosmic-theme.nix`)
- Use `cosmic-ext-ctl` in an activation script
- Document manual setup via COSMIC Settings if declarative config isn't feasible

Bind `Super+C` (or alternative if it conflicts) to `claude-quick`.

**Step 4: Validate**

Run: `nix flake check`
Expected: pass

**Step 5: Commit**

```bash
git add modules/common/system.nix  # or wherever the launcher landed
git commit -m "feat: Super+C keybinding for Claude Code quick-action"
```

**Step 6: Test (after rebuild)**

Press `Super+C` — should open a floating Ghostty window with Claude Code.

---

## Task 5: Desktop Notifications from Claude Code

**Files:**
- Modify: `modules/common/system.nix` (add libnotify to system packages)
- Modify: `home/claude-code.nix` (add Notification hook to settings)

**Step 1: Add libnotify to system packages**

In `modules/common/system.nix`, add to `environment.systemPackages`:
```nix
libnotify  # notify-send for Claude Code notifications
```

**Step 2: Add notification hook to `home/claude-code.nix`**

Add to the `claudeSettings` attrset:

```nix
hooks = {
  Notification = [
    {
      type = "command";
      command = "${pkgs.libnotify}/bin/notify-send --app-name='Claude Code' --icon=claude-logo \"$CLAUDE_NOTIFICATION_TITLE\" \"$CLAUDE_NOTIFICATION_BODY\"";
    }
  ];
};
```

Note: Check the exact environment variable names Claude Code passes to notification hooks. They may be `$TITLE` and `$BODY` or similar. Verify against Claude Code documentation.

**Step 3: Validate**

Run: `nix flake check`
Expected: pass

**Step 4: Commit**

```bash
git add modules/common/system.nix home/claude-code.nix
git commit -m "feat: desktop notifications for Claude Code via COSMIC"
```

**Step 5: Test (after rebuild)**

Start a Claude Code session and wait for a notification event (or trigger one by completing a long task). Verify a COSMIC desktop toast appears.

---

## Task 6: Final Integration + Documentation

**Files:**
- Modify: `docs/MODULES.md` (update with new modules)
- Modify: `docs/IMPLEMENTATION_STATUS.md` (mark phase 4 complete)

**Step 1: Update documentation**

Use the doc-generator agent or manually update `docs/MODULES.md` to include:
- `modules/common/snapshots.nix` — snapper configuration
- `modules/apps/mcp-system-health/` — system health MCP server
- `home/claude-code.nix` — declarative Claude Code configuration

**Step 2: Apply to live system**

```bash
sudo nixos-rebuild switch --flake ~/.config/claudeos#$(hostname)
```

Verify:
- [ ] `~/.claude/settings.json` is generated from Nix
- [ ] `~/.claude/.mcp.json` includes both `nixos` and `system-health` servers
- [ ] `snapper -c root list` works
- [ ] `snapper -c home list` works (without sudo)
- [ ] `rebuild` function creates pre/post snapshots
- [ ] `claude-quick` command opens Ghostty with Claude Code
- [ ] `Super+C` keybinding triggers claude-quick
- [ ] Notifications appear when Claude Code fires events
- [ ] Claude Code can query system health ("How's my system?")

**Step 3: Clean up stale files**

```bash
rm -f ~/.claude/statusline-command.sh  # now managed by Nix
```

**Step 4: Final commit + push**

```bash
git add docs/
git commit -m "docs: update documentation for phase 4 claude integration"
git push
```

---

## Build Order Summary

```
Task 1: Declarative Claude Code Config ──── foundation for Tasks 3 + 5
Task 2: Snapper Snapshots ──────────────── independent, needed by Task 3 (snapshot_list tool)
Task 3: System Health MCP Server ────────── depends on Tasks 1 + 2
Task 4: COSMIC Keybinding ──────────────── independent (needs research)
Task 5: Desktop Notifications ──────────── depends on Task 1
Task 6: Integration + Docs ─────────────── depends on all above
```

Recommended execution: 1 → 2 → 3 → 5 → 4 → 6
Tasks 4 and 5 can be parallelized if Task 1 is complete.
