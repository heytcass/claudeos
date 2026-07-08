{ config, ... }:

{
  # Public signing keys this machine trusts for signature verification —
  # one line per enrolled machine (principal, then key)
  xdg.configFile."git/allowed-signers".text = ''
    # transporter (enrolled 2026-07-07)
    heytcass@gmail.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC2ymFZpbiPjS7gcbJIf3DmHK1KLbCjqGVXRuKP3joXo
  '';

  programs.git = {
    enable = true;

    # Git configuration using settings format
    settings = {
      user = {
        name = "Tom Cassady";
        email = "heytcass@gmail.com";
      };

      # Aliases
      alias = {
        st = "status";
        co = "checkout";
        br = "branch";
        ci = "commit";
        last = "log -1 HEAD";
        unstage = "reset HEAD --";
        amend = "commit --amend";
        graph = "log --graph --oneline --decorate --all";
      };

      # Default branch name
      init.defaultBranch = "main";

      # Pull strategy - rebase for cleaner history
      pull.rebase = true;

      # Push strategy
      push = {
        default = "simple";
        autoSetupRemote = true;
      };

      # Color UI
      color.ui = true;

      # Diff configuration
      diff.algorithm = "histogram";

      # Merge configuration
      merge.conflictstyle = "diff3";

      # Rebase configuration
      rebase.autoStash = true;

      # Reuse recorded conflict resolutions
      rerere.enabled = true;

      # Auto-prune stale remote-tracking branches on fetch
      fetch.prune = true;

      # Show diff in commit message editor
      commit.verbose = true;

      # Core settings + status/diff performance — this repo is walked
      # constantly (starship, statusline, agent loops), so let git cache
      # instead of re-scanning
      core = {
        autocrlf = "input";
        fsmonitor = true;
        untrackedCache = true;
      };
      fetch.writeCommitGraph = true;

      # Highlight moved lines distinctly from add/delete in diffs
      diff.colorMoved = "default";

      # GitHub credential helper comes from programs.gh.gitCredentialHelper
      # (home/shell/cli-tools.nix) — don't duplicate it here

      # SSH-based commit signing (simpler than GPG, uses existing SSH key)
      gpg.format = "ssh";
      user.signingkey = "~/.ssh/id_ed25519.pub";
      commit.gpgSign = true;
      tag.gpgSign = true;
      # Without an allowed-signers file, git log --show-signature can't
      # verify even our own commits locally (per-machine keys; append each
      # machine's pubkey as it's enrolled)
      gpg.ssh.allowedSignersFile = "${config.home.homeDirectory}/.config/git/allowed-signers";
    };

    # Git LFS (Large File Storage)
    lfs.enable = true;
  };

  # GitHub CLI is configured in home/shell/cli-tools.nix (programs.gh)

  # Delta - Better git diffs (separate program)
  # Colors are managed by Stylix - see modules/desktop/theme.nix
  programs.delta = {
    enable = true;
    enableGitIntegration = true;

    options = {
      features = "line-numbers decorations";
      line-numbers = true;
      side-by-side = false;
      navigate = true; # Jump between files with n/N
      hyperlinks = true; # Clickable file paths in supporting terminals
    };
  };
}
