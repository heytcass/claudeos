#!/usr/bin/env bash
# Stop hook: a session worktree with work that isn't on main is how the
# machine ends up half-built — branches nobody merged, worktrees nobody
# removed. When a session stops with unlanded commits, hold the stop ONCE and
# make Claude decide: land it (claudeos-land) or tell the user why not.
# Uncommitted edits alone are work in progress, not forgotten work, so they
# never trigger a nudge — that cost an extra round on every mid-work turn.
# Nudges once per distinct state (HEAD + dirty tree), so a turn that ends on
# a question to the user costs one extra round, not one per turn.
# Headless lanes (CLAUDEOS_HEADLESS) are exempt — the wish lane only proposes.
[[ -n "${CLAUDEOS_HEADLESS:-}" ]] && exit 0
input=$(cat)
[[ "$(jq -r '.stop_hook_active // false' <<<"$input")" == true ]] && exit 0
cwd=$(jq -r '.cwd // empty' <<<"$input")
sid=$(jq -r '.session_id // "unknown"' <<<"$input")
cd "${cwd:-${CLAUDE_PROJECT_DIR:-.}}" 2>/dev/null || exit 0

gd=$(git rev-parse --path-format=absolute --git-dir 2>/dev/null) || exit 0
cd_=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
[[ "$gd" == "$cd_" ]] && exit 0 # shared checkout: nothing of its own to land
[[ -f "$(git rev-parse --show-toplevel)/flake.nix" ]] || exit 0

ahead=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo 0)
dirty=$(git status --porcelain 2>/dev/null)
[[ "$ahead" -eq 0 ]] && exit 0

# A squash merge leaves the branch's own commits off main forever, so "ahead"
# alone misreads a PR merged outside claudeos-land as unlanded. A clean tree
# whose HEAD is exactly a merged PR's head has landed (same test as the sweep).
if [[ -z "$dirty" ]] && branch=$(git symbolic-ref -q --short HEAD) &&
  timeout 10 gh pr list --head "$branch" --state merged --json headRefOid \
    -q '.[].headRefOid' 2>/dev/null | grep -qx "$(git rev-parse HEAD)"; then
  exit 0
fi

state="$(git rev-parse HEAD) $(sha1sum <<<"$dirty" | cut -c1-12)"
mark="${XDG_STATE_HOME:-$HOME/.local/state}/claudeos/land-nudge/$sid"
[[ "$(cat "$mark" 2>/dev/null)" == "$state" ]] && exit 0
mkdir -p "$(dirname "$mark")" && echo "$state" >"$mark"

what="$ahead commit(s) not on main"
[[ -n "$dirty" ]] && what="$what, plus uncommitted changes"
reason="This worktree has unlanded work ($what). Decide now:
- Verified complete (builds, and anything the user had to see or approve is seen and approved)? Commit with explicit paths, then run claudeos-land in the background — it validates, squash-merges the PR, fast-forwards ~/.config/claudeos, switches this host and sweeps landed worktrees. Report what it printed.
- Not complete (waiting on the user's answer or visual check, a failing build, more steps)? Say in one line what is still open, and stop.
Never leave the machine half-built without saying so."
jq -n --arg r "$reason" '{decision:"block",reason:$r}'
exit 0
