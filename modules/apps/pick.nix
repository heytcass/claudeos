# modules/apps/pick.nix — `claudeos-pick`: "point at it". The CLI face of the
# selector's pick mode (home/quickshell/RegionShot.qml), so an agent can ask
# the user to click a window or drag a box and get its identity back:
#
#   claudeos-pick [--prompt TEXT] [--timeout SECONDS]
#
# Prints one JSON object on stdout:
#   {"cancelled":false,"monitor":"eDP-1","scale":2,"x":..,"y":..,"width":..,
#    "height":..,"global":{x,y,width,height},"window":{address,class,
#    initialClass,title,pid,workspace,floating}|null}
# x/y are monitor-relative logical px (what a screenshot of that monitor
# shows); `global` is Hyprland's layout space (`hyprctl clients -j`). `window`
# is null for a dragged box that is not exactly a window.
#
# Exit 0 picked · 1 the user pressed Esc · 2 timed out / no bar · 3 usage.
#
# Quickshell IPC is synchronous and cannot block on the user, so the bar
# answers through a file: this script picks a token, calls the IPC, and waits
# for $XDG_RUNTIME_DIR/claudeos-pick/TOKEN.json (inotify, polling fallback).
# qs comes from the session PATH on purpose: IPC must reach the running bar.
{ lib, pkgs, ... }:
let
  claudeLib = import ../../lib/claude-script.nix { inherit pkgs lib; };
in
{
  environment.systemPackages = [
    (claudeLib.mkClaudeScriptBin {
      name = "claudeos-pick";
      runtimeInputs = [ pkgs.inotify-tools ];
      text = ''
        usage() {
          cat >&2 <<'EOF'
        usage: claudeos-pick [--prompt TEXT] [--timeout SECONDS]
        Freezes the focused monitor and asks the user to click a window or drag
        a box. Prints the choice as JSON (window identity + geometry).
        Exit 0 picked, 1 cancelled with Esc, 2 timed out or no bar, 3 usage.
        EOF
          exit 3
        }

        prompt=""
        timeout=120
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --prompt) prompt="''${2:-}"; shift 2 ;;
            --timeout)
              [[ "''${2:-}" =~ ^[0-9]+$ ]] || usage
              timeout="$2"; shift 2 ;;
            -h | --help) usage ;;
            *) usage ;;
          esac
        done

        dir="''${XDG_RUNTIME_DIR:-/tmp}/claudeos-pick"
        mkdir -p "$dir"
        chmod 700 "$dir"
        token="$(date +%s)-$$"
        out="$dir/$token.json"
        rm -f "$out" "$out.tmp"
        cleanup() { rm -f "$out" "$out.tmp"; }
        trap cleanup EXIT

        if ! qs ipc call regionshot pick "$token" "$prompt" >/dev/null 2>&1; then
          echo "claudeos-pick: the bar is not reachable (is the Hyprland session up?)" >&2
          exit 2
        fi

        # The bar renames the file into place, so a single close/moved event on
        # the directory is the signal; inotifywait returns 2 on timeout.
        if [[ ! -e "$out" ]]; then
          inotifywait -q -q -t "$timeout" -e moved_to -e close_write --include "/$token\\.json\$" "$dir" || true
        fi
        if [[ ! -e "$out" ]]; then
          # Hand the bar back to the user, then say so.
          qs ipc call regionshot cancel "$token" >/dev/null 2>&1 || true
          echo "claudeos-pick: no pick within ''${timeout}s" >&2
          exit 2
        fi

        result=$(cat "$out")
        printf '%s\n' "$result"
        if [[ "$(jq -r '.cancelled' <<<"$result")" == "true" ]]; then
          exit 1
        fi
      '';
    })
  ];
}
