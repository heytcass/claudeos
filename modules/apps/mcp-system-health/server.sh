# ClaudeOS System Health MCP Server — bash + jq rewrite (no Python dependency).
# This file is inlined by default.nix after the shebang and PATH setup.

read_message() {
  local content_length=0 line
  while IFS= read -r line; do
    line="${line%$'\r'}"
    [[ -z "$line" ]] && break
    if [[ "$line" == Content-Length:* ]]; then
      content_length="${line#Content-Length: }"
      content_length="${content_length// /}"
    fi
  done

  [[ "$content_length" -eq 0 ]] && return 1

  local body
  IFS= read -r -N "$content_length" body
  printf '%s' "$body"
}

write_message() {
  local body="$1"
  printf 'Content-Length: %d\r\n\r\n%s' "${#body}" "$body"
}

handle_tool() {
  local name="$1" args="$2"
  case "$name" in
    disk_usage)
      echo "=== BTRFS USAGE ==="
      btrfs fi usage / 2>/dev/null || echo "btrfs not available"
      echo ""
      echo "=== DISK FREE ==="
      df -h --type=btrfs --type=vfat 2>/dev/null || echo "(no btrfs/vfat mounts)"
      ;;
    failed_services)
      systemctl --failed --no-pager 2>/dev/null || echo "(could not query services)"
      ;;
    recent_errors)
      local count
      count=$(printf '%s' "$args" | jq -r '.count // 50')
      journalctl -p err -n "$count" --no-pager 2>/dev/null || echo "(could not read journal)"
      ;;
    system_status)
      echo "UPTIME: $(uptime 2>/dev/null || echo '(unknown)')"
      echo ""
      echo "MEMORY:"
      free -h 2>/dev/null || echo "(not available)"
      echo ""
      echo "CPU TEMP:"
      local found=false
      for f in /sys/class/thermal/thermal_zone*/temp; do
        [[ -f "$f" ]] || continue
        local raw
        raw=$(cat "$f" 2>/dev/null) || continue
        echo "  $(basename "$(dirname "$f")"): $(( raw / 1000 )).$(( (raw % 1000) / 100 ))C"
        found=true
      done
      [[ "$found" == false ]] && echo "  (not available)"
      echo ""
      if [[ -f /sys/class/power_supply/BAT0/capacity ]]; then
        echo "BATTERY: $(cat /sys/class/power_supply/BAT0/capacity)% ($(cat /sys/class/power_supply/BAT0/status))"
      else
        echo "BATTERY: (not present)"
      fi
      ;;
    snapshot_list)
      echo "=== ROOT SNAPSHOTS ==="
      snapper -c root list 2>/dev/null || echo "root config not found"
      echo ""
      echo "=== HOME SNAPSHOTS ==="
      snapper -c home list 2>/dev/null || echo "home config not found"
      ;;
    network_status)
      echo "=== STATUS ==="
      nmcli general status 2>/dev/null || echo "nmcli not available"
      echo ""
      echo "=== ACTIVE CONNECTIONS ==="
      nmcli connection show --active 2>/dev/null || echo "(no active connections)"
      ;;
    nix_store_size)
      local size
      size=$(timeout 10 du -sh /nix/store 2>/dev/null | cut -f1) || size="(timed out)"
      echo "NIX STORE SIZE: ${size}"
      echo ""
      echo "=== GC TIMER ==="
      systemctl status nix-gc.timer --no-pager 2>/dev/null | head -5 || true
      ;;
    scrub_status)
      btrfs scrub status / 2>/dev/null || echo "scrub status not available"
      ;;
    *)
      echo "Unknown tool: ${name}"
      ;;
  esac
}

TOOLS='[{"name":"disk_usage","description":"Show btrfs filesystem usage and disk space","inputSchema":{"type":"object","properties":{}}},{"name":"failed_services","description":"List any failed systemd services","inputSchema":{"type":"object","properties":{}}},{"name":"recent_errors","description":"Show recent error-level journal entries","inputSchema":{"type":"object","properties":{"count":{"type":"integer","description":"Number of entries (default 50)","default":50}}}},{"name":"system_status","description":"System overview: uptime, load, memory, CPU temp, battery","inputSchema":{"type":"object","properties":{}}},{"name":"snapshot_list","description":"List btrfs snapshots managed by snapper","inputSchema":{"type":"object","properties":{}}},{"name":"network_status","description":"NetworkManager status and active connections","inputSchema":{"type":"object","properties":{}}},{"name":"nix_store_size","description":"Nix store disk usage and GC status","inputSchema":{"type":"object","properties":{}}},{"name":"scrub_status","description":"Last btrfs scrub result","inputSchema":{"type":"object","properties":{}}}]'

while true; do
  msg=$(read_message) || break

  method=$(printf '%s' "$msg" | jq -r '.method // ""')
  msg_id=$(printf '%s' "$msg" | jq '.id')

  case "$method" in
    initialize)
      resp=$(jq -n --argjson id "$msg_id" '{
        jsonrpc: "2.0", id: $id,
        result: {
          protocolVersion: "2024-11-05",
          capabilities: {tools: {}},
          serverInfo: {name: "claudeos-system-health", version: "2.0.0"}
        }
      }')
      write_message "$resp"
      ;;

    notifications/initialized)
      ;;

    tools/list)
      resp=$(jq -n --argjson id "$msg_id" --argjson tools "$TOOLS" '{
        jsonrpc: "2.0", id: $id, result: {tools: $tools}
      }')
      write_message "$resp"
      ;;

    tools/call)
      tool_name=$(printf '%s' "$msg" | jq -r '.params.name // ""')
      tool_args=$(printf '%s' "$msg" | jq -c '.params.arguments // {}')
      result_text=$(handle_tool "$tool_name" "$tool_args" 2>&1) || true
      resp=$(jq -n --argjson id "$msg_id" --arg text "$result_text" '{
        jsonrpc: "2.0", id: $id,
        result: {content: [{type: "text", text: $text}]}
      }')
      write_message "$resp"
      ;;

    *)
      if [[ "$msg_id" != "null" ]]; then
        resp=$(jq -n --argjson id "$msg_id" --arg m "$method" '{
          jsonrpc: "2.0", id: $id,
          error: {code: -32601, message: ("Method not found: " + $m)}
        }')
        write_message "$resp"
      fi
      ;;
  esac
done
