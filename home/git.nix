{ config, lib, pkgs, ... }:

{
  programs.git = {
    enable = true;

    # User identity - left unconfigured for manual setup or Phase 5 secrets
    # userName = "Your Name";
    # userEmail = "your.email@example.com";

    # Git configuration using settings format
    settings = {
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

      # Core settings
      core = {
        editor = "code";
        autocrlf = "input";
      };
    };

    # Git LFS (Large File Storage)
    lfs.enable = true;
  };

  # Delta - Better git diffs (separate program)
  programs.delta = {
    enable = true;
    enableGitIntegration = true;

    options = {
      features = "line-numbers decorations";
      syntax-theme = "TwoDark";
      plus-style = "syntax #003800";
      minus-style = "syntax #3f0001";
      line-numbers = true;
      side-by-side = false;
    };
  };
}
