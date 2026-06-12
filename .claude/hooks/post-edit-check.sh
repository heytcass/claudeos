#!/usr/bin/env bash
# PostToolUse(Edit|Write) hook: auto-format the touched .nix file and feed
# parse errors straight back to the agent (exit 2 routes stderr into context),
# so syntax mistakes are fixed immediately instead of at the failed build.
input=$(cat)
file=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$file" ] && exit 0
case "$file" in
*.nix) ;;
*) exit 0 ;;
esac
[ -f "$file" ] || exit 0

command -v nixfmt >/dev/null 2>&1 && nixfmt "$file" 2>/dev/null

if command -v nix-instantiate >/dev/null 2>&1; then
  if ! err=$(nix-instantiate --parse "$file" 2>&1 >/dev/null); then
    {
      echo "Nix parse error in $file (file was auto-formatted; the error is in your edit):"
      echo "$err"
    } >&2
    exit 2
  fi
fi
exit 0
