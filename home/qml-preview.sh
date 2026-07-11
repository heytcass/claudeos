#!/usr/bin/env bash
# qml-preview — fast-reload the bespoke Quickshell bar from repo source and
# screenshot it, WITHOUT a NixOS rebuild. Part of the `/qml-dial-in` loop.
#
# Copies the DEPLOYED ~/.config/quickshell (for the generated Theme.qml +
# cava.conf), overlays the repo's hand-authored home/quickshell/*.qml, stops the
# running bar, launches the preview, and grabs a screenshot. The next
# `nixos-rebuild` restores the real bar. Must run inside the Hyprland session.
#
# Usage: qml-preview [screenshot-path]   (default /tmp/qs-preview.png)
set -uo pipefail

repo="${CLAUDEOS_DIR:-$HOME/.config/claudeos}/home/quickshell"
deployed="$HOME/.config/quickshell"
dest=/tmp/qs-preview
shot="${1:-/tmp/qs-preview.png}"
log=/tmp/qs-preview.log

if ! hyprctl version >/dev/null 2>&1; then
  echo "qml-preview: not in a Hyprland session (grim/qs need it)." >&2
  exit 1
fi
[ -d "$deployed" ] || { echo "qml-preview: no deployed config at $deployed" >&2; exit 1; }

# scratch = deployed (Theme.qml + cava.conf) + repo QML overlaid
rm -rf "$dest"
cp -rL "$deployed" "$dest"
chmod -R u+w "$dest"
cp "$repo"/*.qml "$dest"/ 2>/dev/null || true

# stop the running bar (match the binary path, never this script's cmdline)
pkill -f 'bin/quickshell' 2>/dev/null || true
sleep 1

setsid qs -p "$dest/shell.qml" >"$log" 2>&1 </dev/null &
sleep 2.5

if grep -qiE 'error|caused|unavailable' "$log"; then
  echo "qml-preview: QML LOAD ERROR — the bar will be blank. Offending chain:" >&2
  grep -iE 'error|caused|unavailable' "$log" | head -20 >&2
  exit 2
fi

grim "$shot" && echo "qml-preview: ok → $shot  (edit home/quickshell, re-run to refresh)"
