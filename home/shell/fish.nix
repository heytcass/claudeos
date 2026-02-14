{ pkgs, ... }:

{
  programs.fish = {
    enable = true;

    # Shell aliases integrating modern CLI tools
    shellAliases = {
      # Modern CLI replacements
      # Note: ls/ll/la/lt are provided by programs.eza in cli-tools.nix
      cat = "bat --style=auto";
      man = "batman";

      # Git shortcuts
      gs = "git status";
      gd = "git diff";
      gl = "git log --oneline --graph --decorate";
      gp = "git pull";

      # System shortcuts
      ".." = "cd ..";
      "..." = "cd ../..";

      # NixOS specific
      zc = "z ~/.config/claudeos";
      rebuild = "sudo nixos-rebuild switch --flake ~/.config/claudeos#(hostname)";
      rebuild-test = "sudo nixos-rebuild test --flake ~/.config/claudeos#(hostname)";
      flake-check = "nix flake check --flake ~/.config/claudeos";
    };

    # Fish abbreviations (expand as you type)
    shellAbbrs = {
      # Git abbreviations
      gco = "git checkout";
      gci = "git commit";
      gca = "git commit --amend";
      gaa = "git add --all";
      gcm = "git checkout main";

      # NixOS operations
      nfmt = "nix fmt";
      ndev = "nix develop";
      nbuild = "nix build";
      nrun = "nix run";
      nshell = "nix shell";
      nrepl = "nix repl";
      nupdate = "nix flake update";

      # System operations
      sctl = "systemctl";
      jctl = "journalctl";
    };

    # Custom functions
    functions = {
      # Create directory and cd into it
      mkcd = "mkdir -p $argv[1]; and cd $argv[1]";

      # Extract archives (delegates to ouch which handles all formats
      # including .xz, .zst, .7z, .rar, .tar.*, .zip, .gz, .bz2, etc.)
      extract = "ouch decompress $argv";

      # Quick git commit
      gcam = "git commit -am $argv";

      # Find large files
      findbig = "du -sh * | sort -h | tail -20";
    };

    # Plugin configuration
    plugins = [
      # fzf integration for Fish
      {
        name = "fzf.fish";
        src = pkgs.fetchFromGitHub {
          owner = "PatrickF1";
          repo = "fzf.fish";
          rev = "v10.3";
          sha256 = "sha256-T8KYLA/r/gOKvAivKRoeqIwE2pINlxFQtZJHpOy9GMM=";
        };
      }

      # Puffer fish for text expansion
      {
        name = "puffer-fish";
        src = pkgs.fetchFromGitHub {
          owner = "nickeb96";
          repo = "puffer-fish";
          rev = "12d062eae0d49f5f6d75a23cb6d1f4e410d24242";
          sha256 = "sha256-2niYj0NLfmVIQguuGTA7RrPIcorJEPkxhH6Dhcy+6Bk=";
        };
      }
    ];

    # Shell init
    interactiveShellInit = ''
      # Disable greeting
      set fish_greeting

      # Add ~/.local/bin to PATH for Claude Code CLI
      fish_add_path ~/.local/bin

      # Themed man pages via batman (bat-extras, uses Stylix terminal palette)

      # System fetch on first shell in terminal
      if not set -q MACCHINA_SHOWN
        set -gx MACCHINA_SHOWN 1
        macchina
      end

      # Vi key bindings (disabled by default, uncomment to enable)
      # fish_vi_key_bindings
    '';
  };
}
