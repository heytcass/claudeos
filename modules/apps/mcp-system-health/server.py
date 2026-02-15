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
