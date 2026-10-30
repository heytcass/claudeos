# modules/common/claude-helpers.nix — shared Claude CLI commands.
#
# claude-name-generation: haiku turns a diff/summary (stdin) into the
#   generation-label slug. Only slug-shaped output ([a-z0-9-]) is accepted —
#   anything else falls back to a timestamp slug; the charset is enforced
#   again at eval time by generation-label.nix. Used by the fish `rebuild`
#   function and the auto-update service.
# claude-commit: haiku writes a conventional-commit message for the dirty
#   tree, then commits and pushes. Used by the fish `rebuild` function.
# claudeos-validate: THE canonical repo validation — flake check + per-host
#   dry-run builds enumerated from the flake itself. CI (validate.yml), the
#   deploy/add-module skills, and the validator/builder agents all defer to
#   this instead of re-spelling the loop (the old hand-rolled `ls hosts/`
#   variants broke as soon as a non-host file landed in hosts/).
# claudeos-land: finish a session worktree in one move — validate, squash-merge
#   its PR, fast-forward the shared checkout, switch this host, and sweep
#   landed worktrees. The shared checkout only ever pulls and deploys.
{ pkgs, lib, ... }:

let
  claudeLib = import ../../lib/claude-script.nix { inherit pkgs lib; };
in
{
  environment.systemPackages = [
    (claudeLib.mkClaudeScriptBin {
      name = "claude-name-generation";
      text = ''
        # Usage: claude-name-generation [--local] [--fallback SLUG] [--out FILE] < input
        # Writes the slug to FILE (default $CLAUDEOS_DIR/generation-label) and prints it.
        #   default: haiku summarizes a DIFF into a slug (fish rebuild path)
        #   --local: derive the slug from input that is ALREADY a summary
        #            (auto-update's changelog) — no second model call for
        #            text a model just wrote (cost doctrine)
        #   --out:   label a worktree's tree instead (claudeos-land) — never
        #            dirty the shared checkout from a session's branch
        fallback="rebuild-$(date +%m%d-%H%M)"
        local_mode=false
        out="$CLAUDEOS_DIR/generation-label"
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --local) local_mode=true; shift ;;
            --fallback) fallback="$2"; shift 2 ;;
            --out) out="$2"; shift 2 ;;
            *) shift ;;
          esac
        done

        input=$(cat)
        slug=""
        if [[ -n "$input" ]]; then
          if $local_mode; then
            # First four >2-char words of the summary, hyphen-joined
            slug=$(echo "$input" | tr '[:upper:]' '[:lower:]' \
              | tr -c 'a-z0-9' ' ' | tr -s ' ' '\n' \
              | awk 'length($0) > 2' | head -4 | paste -sd- -)
          else
            slug=$(claude_text haiku "Summarize this NixOS change as a slug of 2-4 lowercase words joined by hyphens, only [a-z0-9-], max 40 chars, no explanation:

        $input")
          fi
          # Only slug-shaped output may name a generation — anything else is
          # rejected in favor of the fallback. The old charset pass (tr -c)
          # MANGLED instead of rejecting: a spend-limit API error became the
          # booted label "You-ve-hit-your-monthly-spend-limit----r". Same
          # doctrine as claude-commit's message shape guard below.
          slug=$(echo "$slug" | cut -c1-40 | sed 's/-*$//')
          [[ "$slug" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || slug=""
        fi
        [[ -z "$slug" ]] && slug="$fallback"

        echo "$slug" > "$out"
        echo "$slug"
      '';
    })

    (claudeLib.mkClaudeScriptBin {
      name = "claude-commit";
      text = ''
        # Usage: claude-commit [DIR] — commit + push DIR (default: the claudeos
        # repo) with a haiku-written conventional-commit message. No-op when
        # the tree is clean or Claude produces no message.
        dir="''${1:-$CLAUDEOS_DIR}"

        dirty=$(git -C "$dir" status --porcelain 2>/dev/null)
        [[ -z "$dirty" ]] && exit 0

        diff_output=$(git -C "$dir" diff 2>/dev/null; git -C "$dir" diff --cached 2>/dev/null)
        [[ -z "$diff_output" ]] && diff_output="$dirty"

        msg=$(claude_text haiku "Generate a concise git commit message for this NixOS config change.
        Use conventional commits (feat:/fix:/chore:). One line, under 72 chars.
        Just the message, nothing else.

        $diff_output")
        [[ -z "$msg" ]] && exit 0
        # Only a one-line conventional-commit shape may become a commit
        # message — CLI error text ("Not logged in · Please run /login")
        # otherwise gets committed verbatim
        [[ "$msg" == *$'\n'* ]] && exit 0
        [[ "$msg" =~ ^[a-z]+(\(.+\))?!?:\ .+$ ]] || exit 0
        # …and a conventional-commit prefix on a chat reply ("chore: I don't
        # see a diff…") is still a chat reply
        claudeos_reply_ok "$msg" 15 || exit 0

        git -C "$dir" add -A \
          && git -C "$dir" commit -m "$msg" \
          || exit 1
        echo "Auto-committed: $msg"

        # The remote moves on its own — auto-update.nix opens PRs that the
        # heal-auto-merge workflow lands — so any rebuild that follows a merge
        # is rejected non-fast-forward. The local commits are near-always
        # generation-label/flake.lock chores, so replay them on top and retry
        # once. Never leave a committed-but-unpushed tree silently: remotes
        # rebuild by pulling this repo.
        #
        # Always push to the same-named branch on origin, never to whatever
        # '@{u}' says: a branch cut with 'checkout -b X origin/main' tracks
        # main under another name, and push.default=simple refuses a bare
        # push there — so the commit would sit local-only. -u re-points the
        # tracking so the next plain 'git push' agrees.
        branch=$(git -C "$dir" symbolic-ref --short -q HEAD)
        if [[ -z "$branch" ]]; then
          echo "Detached HEAD — commit is local only, push by hand." >&2
          exit 1
        fi
        git -C "$dir" push -u origin HEAD && exit 0

        upstream="origin/$branch"
        echo "Push rejected — replaying onto $upstream…"

        if ! git -C "$dir" fetch origin; then
          echo "Fetch failed — commit is local only, push by hand." >&2
          exit 1
        fi
        if ! git -C "$dir" rebase "$upstream"; then
          git -C "$dir" rebase --abort
          echo "Rebase onto $upstream conflicts — resolve by hand, then: git push -u origin HEAD" >&2
          exit 1
        fi
        if ! git -C "$dir" push -u origin HEAD; then
          echo "Push still rejected after rebase — commit is local only." >&2
          exit 1
        fi
        echo "Rebased onto $upstream and pushed."
      '';
    })

    (claudeLib.mkClaudeScriptBin {
      name = "claudeos-validate";
      runtimeInputs = [ pkgs.nix ];
      text = ''
        # Usage: claudeos-validate [DIR] — validate a claudeos checkout: stage
        # untracked files (flakes only see tracked ones), nix flake check,
        # then a --dry-run eval of every host the flake actually defines.
        # DIR defaults to the checkout you're standing in (a session
        # worktree), else the shared one — validating ~/.config/claudeos from
        # a worktree would green-light a tree the change isn't even in.
        dir="''${1:-}"
        if [[ -z "$dir" ]]; then
          dir=$(git rev-parse --show-toplevel 2>/dev/null) || dir=""
          [[ -n "$dir" && -f "$dir/flake.nix" ]] || dir="$CLAUDEOS_DIR"
        fi
        cd "$dir" || exit 1
        echo "claudeos-validate: $dir"

        untracked=$(git ls-files --others --exclude-standard)
        if [[ -n "$untracked" ]]; then
          # shellcheck disable=SC2086
          git add -N $untracked
          echo "claudeos-validate: staged (intent-only) untracked: $untracked"
        fi

        echo "── nix flake check"
        nix flake check --no-build || exit 1

        for host in $(nix flake show --json 2>/dev/null | jq -r '.nixosConfigurations | keys[]'); do
          echo "── dry-run build: $host"
          nix build ".#nixosConfigurations.$host.config.system.build.toplevel" --dry-run || exit 1
        done

        echo "claudeos-validate: all hosts eval clean"
      '';
    })

    (claudeLib.mkClaudeScriptBin {
      name = "claudeos-land";
      runtimeInputs = [ pkgs.gh ];
      text = ''
        # Usage: claudeos-land [--no-deploy] — run inside a session worktree
        # once its work is verified. Lands it end to end so the machine is
        # never left half-built: rebase on origin/main → label the generation
        # → claudeos-validate → push → PR → squash-merge → fast-forward the
        # shared checkout → nixos-rebuild switch here → sweep landed worktrees.
        #        claudeos-land --gc — only the sweep.
        # The session's own worktree goes when the app archives the session
        # (auto-archive on PR merge); everything else merged is removed here.
        deploy=true
        gc_only=false
        case "''${1:-}" in
          --no-deploy) deploy=false ;;
          --gc) gc_only=true ;;
        esac

        # Remove worktrees whose work is on main. App session worktrees
        # (.claude/worktrees/) belong to the app — a live session may sit in
        # one — so they're reported, never removed.
        sweep() {
          git -C "$CLAUDEOS_DIR" worktree prune
          git -C "$CLAUDEOS_DIR" worktree list --porcelain |
            awk '/^worktree /{p=$2} /^branch /{print p, $2}' |
            while read -r wt ref; do
              [[ "$wt" == "$CLAUDEOS_DIR" || "$wt" == "''${top:-}" ]] && continue
              b=''${ref#refs/heads/}
              head=$(git -C "$wt" rev-parse HEAD 2>/dev/null) || continue
              landed=false
              # Squash merges leave no ancestry, so a merged PR at this exact
              # head counts too. A branch with commits past its merged PR is
              # new work and stays.
              if git -C "$CLAUDEOS_DIR" merge-base --is-ancestor "$head" origin/main ||
                gh pr list --head "$b" --state merged --json headRefOid -q '.[].headRefOid' 2>/dev/null | grep -qx "$head"; then
                landed=true
              fi
              $landed || continue
              if [[ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]]; then
                echo "sweep: keeping $wt — landed, but has uncommitted changes"
              elif [[ "$wt" == */.claude/worktrees/* ]]; then
                echo "sweep: $wt is landed — the app removes it when its session is archived"
              else
                git -C "$CLAUDEOS_DIR" worktree remove "$wt" && git -C "$CLAUDEOS_DIR" branch -D "$b" >/dev/null &&
                  echo "sweep: removed $wt ($b)"
              fi
            done
        }

        if $gc_only; then
          cd "$CLAUDEOS_DIR" || exit 1
          git -C "$CLAUDEOS_DIR" fetch -q origin
          sweep
          exit 0
        fi

        top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "claudeos-land: not in a git checkout" >&2; exit 1; }
        cd "$top" || exit 1
        if [[ "$(git rev-parse --git-dir)" == "$(git rev-parse --git-common-dir)" ]]; then
          echo "claudeos-land: $top is the shared checkout — land from a session worktree; the shared checkout only pulls and deploys." >&2
          exit 1
        fi
        branch=$(git symbolic-ref --short -q HEAD) || { echo "claudeos-land: detached HEAD — check out a branch first" >&2; exit 1; }
        if [[ -n "$(git status --porcelain)" ]]; then
          echo "claudeos-land: uncommitted changes — commit them (explicit paths) or drop them first:" >&2
          git status --short >&2
          exit 1
        fi

        git fetch -q origin || exit 1
        # Every land commits its own generation-label, so two lands in flight
        # always collide on it. The label is rewritten just below anyway: take
        # the replayed commit's side and carry on. Any other conflict is real.
        git rebase -q origin/main >/dev/null 2>&1
        while [[ -d "$(git rev-parse --git-path rebase-merge)" ]]; do
          conflicts=$(git diff --name-only --diff-filter=U)
          if [[ "$conflicts" != generation-label ]]; then
            git rebase --abort
            echo "claudeos-land: $branch conflicts with origin/main in:" >&2
            echo "''${conflicts:-  (no conflicted files — the rebase stopped for another reason)}" >&2
            echo "Resolve with: git rebase origin/main" >&2
            exit 1
          fi
          git checkout -q --theirs -- generation-label && git add generation-label
          if git diff --cached --quiet; then
            git rebase --skip >/dev/null 2>&1
          else
            GIT_EDITOR=true git rebase --continue >/dev/null 2>&1
          fi
        done
        if [[ -z "$(git rev-list origin/main..HEAD)" ]]; then
          echo "claudeos-land: nothing to land — $branch has no commits beyond origin/main."
          sweep
          exit 0
        fi

        # Name the generation this work becomes, from its own commit subjects
        # (--local: no model call for text a model already wrote).
        git log --reverse --format=%s origin/main..HEAD |
          sed -E 's/^[a-z]+(\([^)]*\))?!?: //' |
          claude-name-generation --local --out "$top/generation-label" \
            --fallback "land-$(date +%m%d-%H%M)" >/dev/null
        if [[ -n "$(git status --porcelain -- generation-label)" ]]; then
          git commit -q -m "chore: set generation label to $(cat generation-label)" -- generation-label
        fi

        claudeos-validate "$top" || { echo "claudeos-land: validation failed — nothing pushed." >&2; exit 1; }

        git push -q --force-with-lease -u origin "HEAD:refs/heads/$branch" || exit 1
        pr=$(gh pr list --head "$branch" --state open --json number -q '.[0].number // empty')
        if [[ -z "$pr" ]]; then
          url=$(gh pr create --base main --head "$branch" --fill) || exit 1
          pr=''${url##*/}
        fi
        # main's ruleset refuses the merge until the required checks pass
        # (lock-gate builds gti and boots a VM on lock bumps), so wait for them.
        # They take a moment to register after a push; none after ~3 min
        # means nothing is required.
        echo "claudeos-land: PR #$pr open — waiting for its required checks…"
        waited=0
        while :; do
          buckets=$(gh pr checks "$pr" --required --json bucket -q '.[].bucket' 2>/dev/null)
          [[ -z "$buckets" && $waited -ge 180 ]] && break
          [[ -n "$buckets" ]] && ! grep -qx pending <<<"$buckets" && break
          if [[ $waited -ge 5400 ]]; then
            echo "claudeos-land: PR #$pr's checks are still running after 90 min — it stays open; rerun claudeos-land to finish." >&2
            exit 1
          fi
          sleep 30
          waited=$((waited + 30))
        done
        if grep -qxE 'fail|cancel' <<<"$buckets"; then
          echo "claudeos-land: PR #$pr failed required checks — it stays open; main and this host are unchanged:" >&2
          gh pr checks "$pr" --required >&2
          exit 1
        fi
        # --match-head-commit: merge exactly the tree that was just validated.
        if ! gh pr merge "$pr" --squash --match-head-commit "$(git rev-parse HEAD)"; then
          echo "claudeos-land: PR #$pr was not merged — it stays open; main and this host are unchanged." >&2
          exit 1
        fi
        git push -q origin --delete "$branch" 2>/dev/null || true
        # The squash commit now holds this branch's content. Re-point the
        # branch at main so a follow-up round starts clean instead of
        # replaying already-merged commits.
        git fetch -q origin
        git reset -q --hard origin/main
        git branch -q --unset-upstream 2>/dev/null || true
        echo "claudeos-land: PR #$pr merged into main."

        # Deploy from the shared checkout — the only tree that tracks main.
        shared_branch=$(git -C "$CLAUDEOS_DIR" symbolic-ref --short -q HEAD || true)
        if [[ "$shared_branch" != main ]]; then
          echo "claudeos-land: $CLAUDEOS_DIR is on '$shared_branch', not main — not touching it. Landed, NOT deployed." >&2
          exit 1
        fi
        # A `rebuild` whose auto-commit was skipped leaves its slug staged in
        # generation-label. It's machine-written and this land's own label
        # commit supersedes it, so drop it rather than let it block the
        # deploy (and the fast-forward, since main just changed that file).
        git -C "$CLAUDEOS_DIR" restore --staged --worktree generation-label 2>/dev/null || true
        # Uncommitted config here would ride into the deploy unreviewed — the
        # 2026-10-29 failure. Only docs/ may be dirty (the journal diary's
        # ledger edits wait there for the next rebuild auto-commit).
        stray=$(git -C "$CLAUDEOS_DIR" status --porcelain --untracked-files=no | cut -c4- | grep -v '^docs/' || true)
        if [[ -n "$stray" ]]; then
          echo "claudeos-land: $CLAUDEOS_DIR has uncommitted config changes — not deploying them. Landed, NOT deployed:" >&2
          echo "$stray" >&2
          exit 1
        fi
        git -C "$CLAUDEOS_DIR" pull -q --ff-only origin main ||
          { echo "claudeos-land: $CLAUDEOS_DIR can't fast-forward to origin/main. Landed, NOT deployed." >&2; exit 1; }

        if $deploy; then
          host=$(hostname)
          # Scoped NOPASSWD rule (auto-update.nix) — no prompt to hang on.
          if /run/wrappers/bin/sudo -n /run/current-system/sw/bin/nixos-rebuild switch --flake "$CLAUDEOS_DIR#$host"; then
            echo "claudeos-land: $host switched to $(cat /run/current-system/nixos-version)"
          else
            echo "claudeos-land: nixos-rebuild switch failed on $host — main has the change, this host does not. Fix forward from a worktree, or: sudo nixos-rebuild switch --rollback" >&2
            exit 1
          fi
        else
          echo "claudeos-land: not deployed (--no-deploy) — run 'rebuild' when ready."
        fi

        sweep
        case "$top" in
          */.claude/worktrees/*) echo "claudeos-land: this worktree goes when the app archives the session (auto-archive on PR merge)." ;;
          *) echo "claudeos-land: remove this worktree when you're done: git worktree remove $top" ;;
        esac
      '';
    })
  ];
}
