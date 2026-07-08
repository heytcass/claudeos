{ pkgs, lib, ... }:

{
  # Modern CLI tools
  home.packages = with pkgs; [
    ripgrep # Fast grep alternative
    fd # Fast find alternative
    jq # JSON processor
    btop # System monitor
    ouch # Universal archive extractor/compressor
    bun # JavaScript runtime (used by Claude Code Telegram plugin)

    # Rust coreutils on the interactive PATH (two-ring applied to coreutils:
    # system scripts keep GNU coreutils, the user shell gets uutils via hiPrio)
    (lib.hiPrio uutils-coreutils-noprefix)

    # Materialize the GitHub token only where it's needed, instead of
    # exporting it into every process from every shell. gh's keyring is the
    # single source of truth. Usage: with-github-token <command...>
    (pkgs.writeShellScriptBin "with-github-token" ''
      GITHUB_PERSONAL_ACCESS_TOKEN="$(gh auth token)" exec "$@"
    '')
  ];

  # eza - Modern ls replacement
  programs.eza = {
    enable = true;
    icons = "auto";
    git = true;
    extraOptions = [
      "--group-directories-first"
      "--header"
    ];
  };

  # zoxide - Smart cd command
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  # bat - Modern cat with syntax highlighting
  programs.bat = {
    enable = true;
    config = {
      # Let Stylix provide the theme (base16-stylix)
      # Override with mkForce only if needed
      style = "numbers,changes,header";
      pager = "less -FR";
    };
    extraPackages = with pkgs.bat-extras; [
      batdiff # Diff with bat
      batman # Man pages with bat
      batgrep # Grep with bat
      batwatch # Watch with bat
    ];
  };

  # fzf - Fuzzy finder configuration
  # fzf configuration (Fish keybindings provided by fzf.fish plugin in fish.nix)
  programs.fzf = {
    enable = true;
    enableFishIntegration = false;

    # Default options
    defaultCommand = "fd --type f --hidden --exclude .git";
    defaultOptions = [
      "--height 40%"
      "--border"
      "--inline-info"
    ];

    # Use bat for preview
    fileWidgetCommand = "fd --type f --hidden --exclude .git";
    fileWidgetOptions = [
      "--preview 'bat --color=always --style=numbers --line-range=:500 {}'"
    ];

    changeDirWidgetCommand = "fd --type d --hidden --exclude .git";
    changeDirWidgetOptions = [
      "--preview 'eza --tree --level=1 --icons {}'"
    ];
  };

  # atuin - Shell history (local only — sync deliberately not used)
  programs.atuin = {
    enable = true;
    enableFishIntegration = true;

    settings = {
      auto_sync = false;

      # UI preferences
      style = "compact";
      show_preview = true;
      inline_height = 20;

      # Search preferences
      search_mode = "fuzzy";
      filter_mode = "global";
    };
  };

  # yazi - TUI file manager configuration
  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
    shellWrapperName = "y"; # New default in 26.05 (was "yy")

    settings = {
      # yazi 25.x renamed the [manager] section to [mgr]
      mgr = {
        show_hidden = false;
        sort_by = "natural";
        sort_dir_first = true;
      };
    };
  };

  # carapace - Multi-shell completion engine
  programs.carapace = {
    enable = true;
    enableFishIntegration = true;
  };

  # GitHub CLI - declarative configuration
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      prompt = "enabled";
    };
    gitCredentialHelper.enable = true;
  };

  # lazygit - TUI git client
  programs.lazygit.enable = true;

  # direnv - Per-project environment management with nix-direnv
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
