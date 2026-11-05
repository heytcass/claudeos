# modules/apps/spotlight.nix — `claudeos-spotlight`: "Claude points". The CLI
# face of the bar's Spotlight overlay (home/quickshell/Spotlight.qml), so a
# lane or agent can SHOW the user where something is without knowing the
# Quickshell IPC syntax:
#
#   claudeos-spotlight rect X Y W H ["text"] [--for SECONDS]
#   claudeos-spotlight window ADDRESS|CLASS ["text"] [--for SECONDS]
#   claudeos-spotlight clear
#
# Coordinates are Hyprland global layout px (`hyprctl clients -j` at/size).
# `window` resolves the geometry here, with the same rule as the QML's own
# `window` IPC (visible windows only; address, then exact class, then class
# substring; most recently focused wins), so a miss is a clear error and a
# non-zero exit rather than a silent no-op. qs and hyprctl come from the
# session's PATH on purpose: IPC must reach the qs that is actually running.
{ lib, pkgs, ... }:
let
  claudeLib = import ../../lib/claude-script.nix { inherit pkgs lib; };
in
{
  environment.systemPackages = [
    (claudeLib.mkClaudeScriptBin {
      name = "claudeos-spotlight";
      text = ''
        usage() {
          cat >&2 <<'EOF'
        usage: claudeos-spotlight rect X Y W H ["text"] [--for SECONDS]
               claudeos-spotlight window ADDRESS|CLASS ["text"] [--for SECONDS]
               claudeos-spotlight clear
        Dims every monitor except the target, rings it, and shows the text
        beside it. Auto-dismisses after 8 s by default (max 60 s); clicks pass
        through to the apps underneath; clicking the callout dismisses it.
        EOF
          exit 2
        }

        cmd="''${1:-}"
        [[ $# -gt 0 ]] && shift

        # Split positionals from --for, wherever it appears.
        ms=0
        args=()
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --for)
              [[ "''${2:-}" =~ ^[0-9]+([.][0-9]+)?$ ]] || usage
              ms=$(awk -v s="$2" 'BEGIN { printf "%d", s * 1000 }')
              shift 2
              ;;
            -h | --help) usage ;;
            *) args+=("$1"); shift ;;
          esac
        done

        ipc() { qs ipc call spotlight "$@"; }

        case "$cmd" in
          rect)
            [[ ''${#args[@]} -ge 4 ]] || usage
            for n in "''${args[@]:0:4}"; do
              [[ "$n" =~ ^-?[0-9]+$ ]] || { echo "claudeos-spotlight: '$n' is not an integer" >&2; exit 2; }
            done
            ipc rect "''${args[0]}" "''${args[1]}" "''${args[2]}" "''${args[3]}" "''${args[4]:-}" "$ms"
            ;;
          window)
            [[ ''${#args[@]} -ge 1 ]] || usage
            q="''${args[0]}"
            geom=$(jq -nr --arg q "$q" \
              --argjson c "$(hyprctl -j clients)" \
              --argjson m "$(hyprctl -j monitors)" '
              ($q | ascii_downcase) as $q
              | (if ($q | startswith("0x")) then $q else "0x" + $q end) as $addr
              | ([$m[] | .activeWorkspace.id, (.specialWorkspace.id // empty)]) as $shown
              | [$c[] | select(.mapped and (.hidden | not) and (.workspace.id as $w | $shown | index($w)))]
              | sort_by(.focusHistoryID) as $v
              | ( [$v[] | select((.address | ascii_downcase) == $addr)]
                + [$v[] | select((.class | ascii_downcase) == $q or (.initialClass | ascii_downcase) == $q)]
                + [$v[] | select(.class | ascii_downcase | contains($q))] )
              | first // empty
              | "\(.at[0]) \(.at[1]) \(.size[0]) \(.size[1])"')
            if [[ -z "$geom" ]]; then
              echo "claudeos-spotlight: no window matching '$q' is visible (it may be on a hidden workspace)" >&2
              exit 1
            fi
            read -r x y w h <<<"$geom"
            echo "$x $y $w $h"
            ipc rect "$x" "$y" "$w" "$h" "''${args[1]:-}" "$ms"
            ;;
          clear)
            ipc clear
            ;;
          *) usage ;;
        esac
      '';
    })
  ];
}
