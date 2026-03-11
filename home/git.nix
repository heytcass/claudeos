{ ... }:

{
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

      # Core settings
      core = {
        autocrlf = "input";
      };

      # GitHub CLI credential helper
      credential.helper = "!gh auth git-credential";

      # SSH-based commit signing (simpler than GPG, uses existing SSH key)
      gpg.format = "ssh";
      user.signingkey = "~/.ssh/id_ed25519.pub";
      commit.gpgSign = true;
      tag.gpgSign = true;
    };

    # Git LFS (Large File Storage)
    lfs.enable = true;
  };

  # GitHub CLI
  programs.gh = {
    enable = true;
    settings.git_protocol = "ssh";
  };

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
