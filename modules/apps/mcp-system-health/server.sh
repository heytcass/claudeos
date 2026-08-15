# ClaudeOS System Health MCP Server — bash + jq rewrite (no Python dependency).
# This file is inlined by default.nix after the shebang and PATH setup.
#
# Transport: newline-delimited JSON-RPC on stdio, per the MCP spec. (The first
# version of this server used LSP-style Content-Length framing, which Claude
# Code never speaks — it sat unreachable until 2026-07-12.)

write_message() {
  printf '%s\n' "$1"
}

# Guard for tools that talk to the live compositor: headless lanes (self-heal,
# auto-update timers) have no HYPRLAND_INSTANCE_SIGNATURE and must get a clear
# "not applicable here" instead of a confusing hyprctl error.
hypr_available() {
  hyprctl version >/dev/null 2>&1
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
    hypr_config_check)
      # Validates config against the Hyprland BINARY via `--verify-config`,
      # which is the check `nix build` cannot do (see CLAUDE.md "Compositor
      # config isn't validated by the build").
      #
      # This used to trial the value live with `hyprctl keyword` + `hyprctl
      # reload`. That was rebuilt 2026-08-15 because `keyword` is gated on
      # CONFIG_LEGACY and `eval` on CONFIG_LUA in src/debug/HyprCtl.cpp —
      # exact mirror images — so a tool built on `keyword` stops working the
      # moment the config migrates to Lua. `--verify-config` is
      # format-agnostic, mutates nothing, needs no reload, and does not
      # require a running session.
      local field value snippet cfg fmt trial tmp out rc
      field=$(printf '%s' "$args" | jq -r '.field // ""')
      value=$(printf '%s' "$args" | jq -r '.value // ""')
      snippet=$(printf '%s' "$args" | jq -r '.snippet // ""')

      # Which config is deployed. Hyprland picks by extension and .lua WINS
      # whenever it exists (src/config/ConfigManager.cpp), so check it first.
      if [[ -f "$HOME/.config/hypr/hyprland.lua" ]]; then
        cfg="$HOME/.config/hypr/hyprland.lua"
        fmt=lua
      elif [[ -f "$HOME/.config/hypr/hyprland.conf" ]]; then
        cfg="$HOME/.config/hypr/hyprland.conf"
        fmt=hyprlang
      else
        echo "No deployed Hyprland config found under ~/.config/hypr/."
        return
      fi

      if [[ -n "$snippet" ]]; then
        trial="$snippet"
      elif [[ -n "$field" && -n "$value" ]]; then
        if [[ "$fmt" == "lua" ]]; then
          echo "Deployed config is Lua ($cfg); field/value is hyprlang shape."
          echo "Pass 'snippet' instead, e.g. snippet='hl.config{ general = { gaps_in = 2 } }'"
          return
        fi
        trial="$field = $value"
      else
        echo "Provide either 'snippet', or both 'field' and 'value' (hyprlang only)."
        echo "Deployed format: $fmt ($cfg)"
        return
      fi

      # Under Lua, --verify-config EXECUTES the config. A top-level
      # hl.exec_cmd runs for real; the same call inside hl.on("hyprland.start")
      # does not. Refuse the dangerous shape rather than spawning processes
      # from a validation tool.
      if [[ "$fmt" == "lua" && "$trial" == *exec_cmd* && "$trial" != *hyprland.start* ]]; then
        echo "Refusing: a top-level hl.exec_cmd EXECUTES during --verify-config."
        echo "Wrap it in hl.on(\"hyprland.start\", function() ... end) and retry."
        return
      fi

      tmp=$(mktemp -d)
      # Keep the original extension — Hyprland selects its parser from it.
      local trialcfg="$tmp/hyprland.${cfg##*.}"
      cat "$cfg" >"$trialcfg"
      printf '\n%s\n' "$trial" >>"$trialcfg"

      # XDG_RUNTIME_DIR is mandatory: without it Hyprland aborts with
      # "XDG_RUNTIME_DIR is not set!" and exit 134 — identically for a good
      # and a bad config, so that abort must never be read as a verdict.
      out=$(XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
        Hyprland --verify-config -c "$trialcfg" 2>&1) && rc=0 || rc=$?
      rm -rf "$tmp"

      echo "format: $fmt   base: $cfg"
      echo "trial:  $trial"
      if [[ "$rc" == 0 ]] && printf '%s' "$out" | grep -q "config ok"; then
        echo "verdict: OK — config parses with the trial applied"
      elif printf '%s' "$out" | grep -q "Config error\|error"; then
        echo "verdict: REJECTED"
        printf '%s\n' "$out" | grep -iE "config error|error|unknown|invalid|expected" | head -10
      else
        echo "verdict: UNVERIFIABLE (rc=$rc) — the verifier could not run; this is NOT a config verdict"
        printf '%s\n' "$out" | tail -5
      fi
      ;;
    hypr_config_errors)
      if ! hypr_available; then
        echo "Not in a Hyprland session (hyprctl unreachable) — this tool only works from the live session."
        return
      fi
      local do_reload
      do_reload=$(printf '%s' "$args" | jq -r '.reload // false')
      if [[ "$do_reload" == "true" ]]; then
        echo "hyprctl reload: $(hyprctl reload 2>&1)"
      fi
      local errs
      errs=$(hyprctl configerrors 2>&1)
      echo "configerrors: ${errs:-(none — green)}"
      ;;
    quickshell_check)
      # Load-checks the bespoke Quickshell bar QML without a NixOS rebuild:
      # deployed ~/.config/quickshell (for generated Theme.qml/cava.conf) +
      # repo *.qml overlaid, same recipe as qml-preview. Briefly stops and
      # restarts the live bar (two instances fight over the layer + the
      # org.freedesktop.Notifications name).
      if ! hypr_available; then
        echo "Not in a Hyprland session (hyprctl unreachable) — this tool only works from the live session."
        return
      fi
      if ! command -v qs >/dev/null 2>&1; then
        echo "quickshell (qs) not on PATH"
        return
      fi
      local qml_dir deployed dest log
      qml_dir=$(printf '%s' "$args" | jq -r '.qml_dir // ""')
      [[ -z "$qml_dir" ]] && qml_dir="${CLAUDEOS_DIR:-$HOME/.config/claudeos}/home/quickshell"
      deployed="$HOME/.config/quickshell"
      if [[ ! -d "$deployed" ]]; then
        echo "No deployed config at $deployed"
        return
      fi
      if [[ ! -d "$qml_dir" ]]; then
        echo "QML source dir not found: $qml_dir (pass qml_dir for worktrees)"
        return
      fi
      dest=$(mktemp -d /tmp/qs-check.XXXXXX)
      log="$dest/load.log"
      cp -rL "$deployed"/. "$dest/"
      chmod -R u+w "$dest"
      cp "$qml_dir"/*.qml "$dest"/ 2>/dev/null || true
      # Anchored cmdline match: the bar runs with no args, so this hits every
      # bar instance (incl. strays) but not the -p preview or unrelated
      # processes that merely mention quickshell. (pkill -x is useless here —
      # the wrapped binary's comm is the truncated ".quickshell-wra"; and an
      # unanchored -f pattern once killed the test harness invoking this tool.)
      pkill -f 'bin/quickshell$' 2>/dev/null || true
      sleep 1
      setsid qs -p "$dest/shell.qml" >"$log" 2>&1 </dev/null &
      sleep 3
      local verdict
      if grep -qiE 'error|caused|unavailable' "$log"; then
        verdict="FAIL — QML load error (the bar would be blank). Offending chain:
$(grep -iE 'error|caused|unavailable' "$log" | head -20)"
      else
        verdict="PASS — $qml_dir loads clean against the deployed Theme.qml."
      fi
      pkill -f "$dest/shell.qml" 2>/dev/null || true
      sleep 1
      setsid qs >/dev/null 2>&1 </dev/null &
      rm -rf "$dest"
      echo "$verdict"
      echo "(live bar restarted)"
      ;;
    *)
      echo "Unknown tool: ${name}"
      ;;
  esac
}

TOOLS='[{"name":"disk_usage","description":"Show btrfs filesystem usage and disk space","inputSchema":{"type":"object","properties":{}}},{"name":"failed_services","description":"List any failed systemd services","inputSchema":{"type":"object","properties":{}}},{"name":"recent_errors","description":"Show recent error-level journal entries","inputSchema":{"type":"object","properties":{"count":{"type":"integer","description":"Number of entries (default 50)","default":50}}}},{"name":"system_status","description":"System overview: uptime, load, memory, CPU temp, battery","inputSchema":{"type":"object","properties":{}}},{"name":"snapshot_list","description":"List btrfs snapshots managed by snapper","inputSchema":{"type":"object","properties":{}}},{"name":"network_status","description":"NetworkManager status and active connections","inputSchema":{"type":"object","properties":{}}},{"name":"nix_store_size","description":"Nix store disk usage and GC status","inputSchema":{"type":"object","properties":{}}},{"name":"scrub_status","description":"Last btrfs scrub result","inputSchema":{"type":"object","properties":{}}},{"name":"hypr_config_check","description":"Validate Hyprland config against the Hyprland binary with --verify-config (nix build cannot check generated config contents). Appends a trial line to the deployed config in a temp copy and parses it — nothing is mutated, no reload, no live session needed. Works for both hyprlang (.conf) and Lua (.lua); the deployed format is auto-detected. Verdicts are OK / REJECTED / UNVERIFIABLE — UNVERIFIABLE means the verifier itself could not run and is NOT a statement about the config.","inputSchema":{"type":"object","properties":{"field":{"type":"string","description":"hyprlang keyword, e.g. windowrule, general:gaps_in (hyprlang configs only; use snippet for Lua)"},"value":{"type":"string","description":"Value to trial, e.g. \"float on, match:class ^(foo)$\""},"snippet":{"type":"string","description":"Raw config text to append verbatim — required for Lua, e.g. hl.config{ general = { gaps_in = 2 } }. Takes precedence over field/value."}},"required":[]}},{"name":"hypr_config_errors","description":"Report hyprctl configerrors for the running Hyprland session (empty = green). Optionally hyprctl reload first to re-parse the deployed config. Only works inside the Hyprland session.","inputSchema":{"type":"object","properties":{"reload":{"type":"boolean","description":"Run hyprctl reload before checking (default false)","default":false}}}},{"name":"quickshell_check","description":"Load-check the bespoke Quickshell bar QML from repo source without a NixOS rebuild: overlays repo *.qml onto a copy of the deployed config (generated Theme.qml/cava.conf) and runs qs -p. One broken QML file blanks the whole bar, so run this before rebuilding. Briefly restarts the live bar. Only works inside the Hyprland session.","inputSchema":{"type":"object","properties":{"qml_dir":{"type":"string","description":"QML source dir to check (default $CLAUDEOS_DIR/home/quickshell — pass explicitly from worktrees)"}}}}]'

while IFS= read -r msg; do
  [[ -z "$msg" ]] && continue

  method=$(printf '%s' "$msg" | jq -r '.method // ""' 2>/dev/null) || continue
  msg_id=$(printf '%s' "$msg" | jq '.id')

  case "$method" in
    initialize)
      resp=$(jq -cn --argjson id "$msg_id" '{
        jsonrpc: "2.0", id: $id,
        result: {
          protocolVersion: "2024-11-05",
          capabilities: {tools: {}},
          serverInfo: {name: "claudeos-system-health", version: "3.0.0"}
        }
      }')
      write_message "$resp"
      ;;

    notifications/initialized)
      ;;

    tools/list)
      resp=$(jq -cn --argjson id "$msg_id" --argjson tools "$TOOLS" '{
        jsonrpc: "2.0", id: $id, result: {tools: $tools}
      }')
      write_message "$resp"
      ;;

    tools/call)
      tool_name=$(printf '%s' "$msg" | jq -r '.params.name // ""')
      tool_args=$(printf '%s' "$msg" | jq -c '.params.arguments // {}')
      result_text=$(handle_tool "$tool_name" "$tool_args" 2>&1) || true
      resp=$(jq -cn --argjson id "$msg_id" --arg text "$result_text" '{
        jsonrpc: "2.0", id: $id,
        result: {content: [{type: "text", text: $text}]}
      }')
      write_message "$resp"
      ;;

    *)
      if [[ "$msg_id" != "null" ]]; then
        resp=$(jq -cn --argjson id "$msg_id" --arg m "$method" '{
          jsonrpc: "2.0", id: $id,
          error: {code: -32601, message: ("Method not found: " + $m)}
        }')
        write_message "$resp"
      fi
      ;;
  esac
done
