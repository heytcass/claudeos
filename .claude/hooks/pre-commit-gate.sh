#!/usr/bin/env bash
# PreToolUse(Bash) hook: CLAUDE.md's "never commit untested NixOS changes",
# enforced. When a `git commit` has staged .nix changes, the flake must
# evaluate (nix flake check --no-build) or the commit is denied with the
# error fed back to the agent. Non-nix commits pass through untouched.
input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
case "$cmd" in
*"git commit"*) ;;
*) exit 0 ;;
esac

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
git diff --cached --name-only 2>/dev/null | grep -q '\.nix$' || exit 0
command -v nix >/dev/null 2>&1 || exit 0

if ! err=$(timeout 180 nix flake check --no-build 2>&1); then
  reason="Blocked: staged .nix changes but 'nix flake check --no-build' fails. Fix evaluation first:
$(echo "$err" | tail -15)"
  jq -n --arg r "$reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
fi
exit 0
