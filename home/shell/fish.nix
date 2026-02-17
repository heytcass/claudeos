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
      # Transient prompt — after a command runs, collapse the full prompt to just ❯
      # Keeps scrollback clean while showing full context on the current line
      starship_transient_prompt_func = "starship module character";

      # Create directory and cd into it
      mkcd = "mkdir -p $argv[1]; and cd $argv[1]";

      # Extract archives (delegates to ouch which handles all formats
      # including .xz, .zst, .7z, .rar, .tar.*, .zip, .gz, .bz2, etc.)
      extract = "ouch decompress $argv";

      # Quick git commit
      gcam = "git commit -am $argv";

      # Find large files
      findbig = "du -sh * | sort -h | tail -20";

      # Claude-powered shell commands (uses haiku for speed/cost)
      fix = ''
                set -l cmd $history[1]
                if test -z "$cmd"
                  echo "No previous command in history."
                  return 1
                end
                set_color --dim
                echo "Asking Claude about: $cmd"
                set_color normal
                set -l suggestion (claude -p "This Fish shell command on NixOS failed: $cmd
        Give me ONLY the corrected command. No explanation, no markdown, no code fences. Just the single command." --model haiku 2>/dev/null)
                if test -z "$suggestion"
                  echo "No suggestion available."
                  return 1
                end
                echo ""
                set_color green
                echo "  $suggestion"
                set_color normal
                echo ""
                read -P "Run? [y/N] " -l confirm
                if string match -qi y $confirm
                  eval $suggestion
                end
      '';

      explain = ''
                if not isatty stdin
                  # Piped input: somecommand | explain
                  set -l input (cat)
                  claude -p "Explain this command output concisely. Be brief and focus on what matters:
        $input" --model haiku 2>/dev/null
                else if test (count $argv) -gt 0
                  # explain "some text" or explain <command>
                  claude -p "Explain this concisely: $argv" --model haiku 2>/dev/null
                else
                  # No args: explain what the last command does
                  set -l cmd $history[1]
                  if test -z "$cmd"
                    echo "No previous command in history."
                    return 1
                  end
                  claude -p "Explain what this shell command does concisely: $cmd" --model haiku 2>/dev/null
                end
      '';

      ask = ''
        if test (count $argv) -eq 0
          echo "Usage: ask <question>"
          return 1
        end
        claude -p "$argv" --model haiku 2>/dev/null
      '';

      # Rebuild NixOS with snapper pre/post snapshots + auto-commit
      rebuild = ''
                # Parse --no-commit flag
                set -l no_commit false
                set -l pass_args
                for arg in $argv
                  if test "$arg" = "--no-commit"
                    set no_commit true
                  else
                    set -a pass_args $arg
                  end
                end

                set -l pre_root (sudo snapper -c root create --type pre --cleanup-algorithm number --print-number --description "pre-rebuild" 2>/dev/null)
                set -l pre_home (snapper -c home create --type pre --cleanup-algorithm number --print-number --description "pre-rebuild" 2>/dev/null)
                if test -n "$pre_root" -a -n "$pre_home"
                  echo "Snapshots: root#$pre_root, home#$pre_home"
                else
                  echo "Warning: snapper pre-snapshots failed (root#$pre_root, home#$pre_home)"
                end

                sudo nixos-rebuild switch --flake ~/.config/claudeos#(hostname) $pass_args
                set -l rebuild_status $status

                if test $rebuild_status -eq 0
                  if test -n "$pre_root"
                    sudo snapper -c root create --type post --pre-number $pre_root --cleanup-algorithm number --description "post-rebuild"
                  end
                  if test -n "$pre_home"
                    snapper -c home create --type post --pre-number $pre_home --cleanup-algorithm number --description "post-rebuild"
                  end
                  if test -n "$pre_root"
                    echo "Rebuild complete. Rollback: sudo snapper -c root undochange $pre_root..(math $pre_root + 1)"
                  else
                    echo "Rebuild complete. (No snapshots for rollback)"
                  end

                  # Auto-commit config changes with Claude-generated message
                  if not $no_commit
                    set -l dirty (git -C ~/.config/claudeos status --porcelain 2>/dev/null)
                    if test -n "$dirty"
                      set -l diff_output (git -C ~/.config/claudeos diff 2>/dev/null; git -C ~/.config/claudeos diff --cached 2>/dev/null)
                      if test -z "$diff_output"
                        set diff_output "$dirty"
                      end
                      set -l msg (claude -p "Generate a concise git commit message for this NixOS config change.
        Use conventional commits (feat:/fix:/chore:). One line, under 72 chars.
        Just the message, nothing else.
        $diff_output" --model haiku 2>/dev/null)
                      if test -n "$msg"
                        git -C ~/.config/claudeos add -A
                        and git -C ~/.config/claudeos commit -m "$msg"
                        and git -C ~/.config/claudeos push
                        and echo "Auto-committed: $msg"
                      end
                    end
                  end
                else
                  echo "Rebuild failed (exit $rebuild_status). Pre-snapshots: root#$pre_root, home#$pre_home"
                end
      '';
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

      # Export GitHub token for MCP server + Claude Code plugins (pulls from gh CLI keyring auth)
      if command -q gh
        set -gx GITHUB_PERSONAL_ACCESS_TOKEN (gh auth token 2>/dev/null)
      end

      # Themed man pages via batman (bat-extras, uses Stylix terminal palette)

      # System fetch + daily brief on first shell in terminal
      if not set -q MACCHINA_SHOWN
        set -gx MACCHINA_SHOWN 1
        macchina
        # ClaudeOS daily brief
        set -l brief_file "$HOME/.cache/claudeos-monitor/daily-brief.txt"
        if test -s "$brief_file"
          echo ""
          cat "$brief_file"
        end
      end

      # Vi key bindings (disabled by default, uncomment to enable)
      # fish_vi_key_bindings
    '';
  };
}
