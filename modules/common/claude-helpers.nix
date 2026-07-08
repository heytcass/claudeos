# modules/common/claude-helpers.nix — shared Claude CLI commands.
#
# claude-name-generation: haiku turns a diff/summary (stdin) into the
#   generation-label slug. The charset rule lives here (and is enforced
#   again at eval time by generation-label.nix). Used by the fish `rebuild`
#   function and the auto-update service.
# claude-commit: haiku writes a conventional-commit message for the dirty
#   tree, then commits and pushes. Used by the fish `rebuild` function.
# claudeos-validate: THE canonical repo validation — flake check + per-host
#   dry-run builds enumerated from the flake itself. CI (validate.yml), the
#   deploy/add-module skills, and the validator/builder agents all defer to
#   this instead of re-spelling the loop (the old hand-rolled `ls hosts/`
#   variants broke as soon as a non-host file landed in hosts/).
{ pkgs, lib, ... }:

let
  claudeLib = import ../../lib/claude-script.nix { inherit pkgs lib; };
in
{
  environment.systemPackages = [
    (claudeLib.mkClaudeScriptBin {
      name = "claude-name-generation";
      text = ''
        # Usage: claude-name-generation [--fallback SLUG] < diff-or-summary
        # Writes the slug to $CLAUDEOS_DIR/generation-label and prints it.
        fallback="rebuild-$(date +%m%d-%H%M)"
        [[ "$1" == "--fallback" && -n "$2" ]] && fallback="$2"

        input=$(cat)
        slug=""
        if [[ -n "$input" ]]; then
          slug=$(claude_text haiku "Summarize this NixOS change as a slug of 2-4 lowercase words joined by hyphens, only [a-z0-9-], max 40 chars, no explanation:

        $input")
          # system.nixos.label only accepts [a-zA-Z0-9:_.-] (generation-label.nix)
          slug=$(echo "$slug" | tr -c 'a-zA-Z0-9:_.-' '-' | cut -c1-40 | sed 's/-*$//')
        fi
        [[ -z "$slug" || "$slug" =~ ^-*$ ]] && slug="$fallback"

        echo "$slug" > "$CLAUDEOS_DIR/generation-label"
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

        git -C "$dir" add -A \
          && git -C "$dir" commit -m "$msg" \
          && git -C "$dir" push \
          && echo "Auto-committed: $msg"
      '';
    })

    (claudeLib.mkClaudeScriptBin {
      name = "claudeos-validate";
      runtimeInputs = [ pkgs.nix ];
      text = ''
        # Usage: claudeos-validate — validate the claudeos repo: stage
        # untracked files (flakes only see tracked ones), nix flake check,
        # then a --dry-run eval of every host the flake actually defines.
        cd "$CLAUDEOS_DIR" || exit 1

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
  ];
}
