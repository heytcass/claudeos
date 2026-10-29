#!/usr/bin/env bash
# PreToolUse(Bash|Edit|Write) hook: ~/.config/claudeos is shared by every
# session, lane and the deploy path — one HEAD, one index, one working tree.
# On 2026-10-29 one session's `git add && git commit` swept up another's
# staged bar work, pushed it and deployed it half-finished. So sessions work in
# their own worktree and the shared checkout only pulls and deploys: here,
# anything that edits files or moves HEAD/index is denied with the way out.
# Headless lanes (CLAUDEOS_HEADLESS, set by claude_headless) are exempt.
[[ -n "${CLAUDEOS_HEADLESS:-}" ]] && exit 0
input=$(cat)
tool=$(jq -r '.tool_name // empty' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input")
[[ -n "$cwd" ]] || cwd="${CLAUDE_PROJECT_DIR:-$PWD}"

# True when DIR sits in a main checkout (not a linked worktree).
is_shared() {
  local d="$1" gd cd
  # A file, or a path not created yet: test its nearest existing directory.
  while [[ ! -d "$d" && "$d" != / ]]; do d=$(dirname "$d"); done
  gd=$(git -C "$d" rev-parse --path-format=absolute --git-dir 2>/dev/null) || return 1
  cd=$(git -C "$d" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
  [[ "$gd" == "$cd" ]] && [[ -f "$(git -C "$d" rev-parse --show-toplevel)/flake.nix" ]]
}

deny() {
  jq -n --arg r "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

way_out="Work in your own worktree instead (EnterWorktree, or: git -C ~/.config/claudeos worktree add <path> -b <branch> origin/main), then land it with claudeos-land. The shared checkout only pulls and deploys."

case "$tool" in
Edit | Write | NotebookEdit)
  f=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input")
  [[ -n "$f" ]] || exit 0
  is_shared "$f" && deny "Blocked: $f is in the shared checkout, which other sessions and the deploy path use too. $way_out"
  exit 0
  ;;
Bash) ;;
*) exit 0 ;;
esac

cmd=$(jq -r '.tool_input.command // empty' <<<"$input")
[[ "$cmd" == *git* ]] || exit 0

# Where a bare `git …` runs: a leading `cd X &&` moves it, else the cwd.
base="$cwd"
if [[ "$cmd" =~ ^[[:space:]]*cd[[:space:]]+([^[:space:];&|]+) ]]; then
  base="${BASH_REMATCH[1]/#\~/$HOME}"
fi

# Every git invocation: optional -C/-c/--flag globals, then the subcommand.
while read -r call; do
  [[ -n "$call" ]] || continue
  sub=${call##* }
  dir="$base"
  if [[ "$call" =~ -C[[:space:]]+([^[:space:]]+) ]]; then
    dir="${BASH_REMATCH[1]//[\"\']/}"
    dir="${dir/#\~/$HOME}"
  fi
  case "$sub" in
  add | commit | checkout | switch | reset | restore | stash | rebase | merge | cherry-pick | revert | am | apply | rm | mv | clean)
    is_shared "$dir" &&
      deny "Blocked: 'git $sub' in the shared checkout ($dir) would move HEAD, the index or files that other sessions share — this is how half-finished work got committed and deployed on 2026-10-29. $way_out"
    ;;
  esac
done < <(grep -oE '(^|[;&|({[:space:]])git([[:space:]]+(-C|-c)[[:space:]]+[^[:space:]]+|[[:space:]]+--[a-z-]+)*[[:space:]]+[a-z-]+' <<<"$cmd" |
  sed -E 's/^[;&|({[:space:]]//')
exit 0
