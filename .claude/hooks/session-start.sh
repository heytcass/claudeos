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

# Sessions share nothing but the repo: in the shared checkout (git-dir ==
# common-dir) every edit and commit collides with other sessions and the
# deploy path, and shared-checkout-guard.sh will deny them. Say so up front.
gd=$(git rev-parse --path-format=absolute --git-dir 2>/dev/null)
if [ -n "$gd" ] && [ "$gd" = "$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" ]; then
  echo "SHARED CHECKOUT: this session is in $(git rev-parse --show-toplevel), which other sessions and the deploy path share. Read and diagnose freely; before editing anything, move into your own worktree (EnterWorktree). Finish worktree work with claudeos-land."
else
  echo "Worktree session: when the work is verified, finish with claudeos-land (validate, merge, deploy, clean up)."
fi
exit 0
