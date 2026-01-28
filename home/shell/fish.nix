{ config, lib, pkgs, ... }:

{
  programs.fish = {
    enable = true;

    # Shell aliases integrating modern CLI tools
    shellAliases = {
      # Modern CLI replacements
      ls = "eza --icons --group-directories-first";
      ll = "eza --icons --group-directories-first -l";
      la = "eza --icons --group-directories-first -la";
      lt = "eza --icons --group-directories-first --tree";
      cat = "bat --style=auto";

      # Git shortcuts
      gs = "git status";
      gd = "git diff";
      gl = "git log --oneline --graph --decorate";
      gp = "git pull";
      gP = "git push";

      # System shortcuts
      ".." = "cd ..";
      "..." = "cd ../..";

      # NixOS specific
      rebuild = "sudo nixos-rebuild switch --flake ~/.config/claudeos#(hostname)";
      rebuild-test = "sudo nixos-rebuild test --flake ~/.config/claudeos#(hostname)";
      flake-check = "cd ~/.config/claudeos && nix flake check";
    };

    # Fish abbreviations (expand as you type)
    shellAbbrs = {
      # Git abbreviations
      gco = "git checkout";
      gci = "git commit";
      gca = "git commit --amend";
      gaa = "git add --all";
      gcm = "git checkout main";
      gph = "git push";
      gpl = "git pull";

      # NixOS operations
      nfmt = "nixpkgs-fmt";
      ndev = "nix develop";
      nbuild = "nix build";
      nrun = "nix run";

      # System operations
      sctl = "systemctl";
      jctl = "journalctl";
    };

    # Custom functions
    functions = {
      # Create directory and cd into it
      mkcd = "mkdir -p $argv[1]; and cd $argv[1]";

      # Extract archives
      extract = ''
        if test -f $argv[1]
          switch $argv[1]
            case '*.tar.bz2'
              tar xjf $argv[1]
            case '*.tar.gz'
              tar xzf $argv[1]
            case '*.bz2'
              bunzip2 $argv[1]
            case '*.gz'
              gunzip $argv[1]
            case '*.tar'
              tar xf $argv[1]
            case '*.tbz2'
              tar xjf $argv[1]
            case '*.tgz'
              tar xzf $argv[1]
            case '*.zip'
              unzip $argv[1]
            case '*.Z'
              uncompress $argv[1]
            case '*'
              echo "'$argv[1]' cannot be extracted via extract()"
          end
        else
          echo "'$argv[1]' is not a valid file"
        end
      '';

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

      # z for directory jumping (alternative to zoxide integration)
      {
        name = "z";
        src = pkgs.fetchFromGitHub {
          owner = "jethrokuan";
          repo = "z";
          rev = "45a9ff6d0932b0e9835cbeb60b9794ba706eef10";
          sha256 = "sha256-pWkEhjbcxXduyKz1mAFo90IuQdX7R8bLCQgb0R+hXs4=";
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

      # Set environment variables
      set -gx EDITOR micro
      set -gx VISUAL micro

      # Enable colored man pages
      set -gx LESS_TERMCAP_mb (printf "\033[01;31m")
      set -gx LESS_TERMCAP_md (printf "\033[01;31m")
      set -gx LESS_TERMCAP_me (printf "\033[0m")
      set -gx LESS_TERMCAP_se (printf "\033[0m")
      set -gx LESS_TERMCAP_so (printf "\033[01;44;33m")
      set -gx LESS_TERMCAP_ue (printf "\033[0m")
      set -gx LESS_TERMCAP_us (printf "\033[01;32m")

      # Vi key bindings (disabled by default, uncomment to enable)
      # fish_vi_key_bindings
    '';
  };
}
