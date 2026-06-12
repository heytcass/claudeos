#!/usr/bin/env bash
# SessionStart hook — every Claude session in this repo starts OS-aware.
# stdout is injected as session context.
echo "Host: $(hostname 2>/dev/null || echo unknown)"
if [ -r /run/current-system/nixos-version ]; then
  echo "Booted generation: $(cat /run/current-system/nixos-version)"
fi
failed_sys=$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}' | paste -sd', ' -)
failed_usr=$(systemctl --user --failed --no-legend --plain 2>/dev/null | awk '{print $1}' | paste -sd', ' -)
[ -n "$failed_sys" ] && echo "FAILED system units: $failed_sys"
[ -n "$failed_usr" ] && echo "FAILED user units: $failed_usr"
exit 0
