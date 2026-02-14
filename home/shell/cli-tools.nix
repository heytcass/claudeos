{ pkgs, ... }:

{
  # Modern CLI tools
  home.packages = with pkgs; [
    ripgrep # Fast grep alternative
    fd # Fast find alternative
    jq # JSON processor
    btop # System monitor
    ouch # Universal archive extractor/compressor
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

  # atuin - Shell history
  programs.atuin = {
    enable = true;
    enableFishIntegration = true;

    settings = {
      # Sync disabled — enable after adding real atuin_key to secrets/secrets.yaml
      # and setting key_path = config.sops.secrets.atuin_key.path
      auto_sync = false;
      sync_address = "";

      # UI preferences
      style = "compact";
      show_preview = true;
      inline_height = 20;

      # Search preferences
      search_mode = "fuzzy";
      filter_mode = "global";

      # History preferences
      update_snapshots = true;
    };
  };

  # yazi - TUI file manager configuration
  programs.yazi = {
    enable = true;
    enableFishIntegration = true;

    settings = {
      manager = {
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

  # direnv - Per-project environment management with nix-direnv
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
