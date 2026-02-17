# ClaudeOS Niri MCP Server — window management for Claude Code.
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
    list_windows)
      niri msg -j windows 2>&1
      ;;
    list_workspaces)
      niri msg -j workspaces 2>&1
      ;;
    focused_window)
      niri msg -j focused-window 2>&1
      ;;
    focused_output)
      niri msg -j focused-output 2>&1
      ;;
    focus_window)
      local id
      id=$(printf '%s' "$args" | jq -r '.id // empty')
      if [[ -z "$id" ]]; then
        echo "Error: 'id' parameter required"
      else
        niri msg action focus-window --id "$id" 2>&1
        echo "Focused window $id"
      fi
      ;;
    close_window)
      niri msg action close-window 2>&1
      echo "Closed focused window"
      ;;
    move_to_workspace)
      local workspace
      workspace=$(printf '%s' "$args" | jq -r '.workspace // empty')
      if [[ -z "$workspace" ]]; then
        echo "Error: 'workspace' parameter required"
      else
        niri msg action move-column-to-workspace "$workspace" 2>&1
        echo "Moved column to workspace $workspace"
      fi
      ;;
    set_column_width)
      local width
      width=$(printf '%s' "$args" | jq -r '.width // empty')
      if [[ -z "$width" ]]; then
        echo "Error: 'width' parameter required (e.g., '33%', '+10%', '-10%')"
      else
        niri msg action set-column-width "$width" 2>&1
        echo "Set column width to $width"
      fi
      ;;
    focus_workspace)
      local workspace
      workspace=$(printf '%s' "$args" | jq -r '.workspace // empty')
      if [[ -z "$workspace" ]]; then
        echo "Error: 'workspace' parameter required"
      else
        niri msg action focus-workspace "$workspace" 2>&1
        echo "Focused workspace $workspace"
      fi
      ;;
    toggle_fullscreen)
      niri msg action fullscreen-window 2>&1
      echo "Toggled fullscreen"
      ;;
    screenshot_screen)
      niri msg action screenshot-screen 2>&1
      echo "Screenshot captured"
      ;;
    *)
      echo "Unknown tool: ${name}"
      ;;
  esac
}

TOOLS='[{"name":"list_windows","description":"List all open windows with their IDs, titles, and app IDs (JSON)","inputSchema":{"type":"object","properties":{}}},{"name":"list_workspaces","description":"List all workspaces with their indices and active status (JSON)","inputSchema":{"type":"object","properties":{}}},{"name":"focused_window","description":"Get details about the currently focused window (JSON)","inputSchema":{"type":"object","properties":{}}},{"name":"focused_output","description":"Get details about the currently focused monitor/output (JSON)","inputSchema":{"type":"object","properties":{}}},{"name":"focus_window","description":"Focus a specific window by its ID","inputSchema":{"type":"object","properties":{"id":{"type":"integer","description":"Window ID to focus"}},"required":["id"]}},{"name":"close_window","description":"Close the currently focused window","inputSchema":{"type":"object","properties":{}}},{"name":"move_to_workspace","description":"Move the focused column to a different workspace","inputSchema":{"type":"object","properties":{"workspace":{"type":"integer","description":"Target workspace number"}},"required":["workspace"]}},{"name":"set_column_width","description":"Set the focused column width. Use absolute (e.g. 33%, 50%) or relative (e.g. +10%, -10%) values","inputSchema":{"type":"object","properties":{"width":{"type":"string","description":"Width value — absolute like 50% or relative like +10%"}},"required":["width"]}},{"name":"focus_workspace","description":"Switch to a workspace by number","inputSchema":{"type":"object","properties":{"workspace":{"type":"integer","description":"Workspace number to focus"}},"required":["workspace"]}},{"name":"toggle_fullscreen","description":"Toggle fullscreen on the focused window","inputSchema":{"type":"object","properties":{}}},{"name":"screenshot_screen","description":"Take a screenshot of the entire screen","inputSchema":{"type":"object","properties":{}}}]'

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
          serverInfo: {name: "claudeos-niri", version: "1.0.0"}
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
