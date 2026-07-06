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

      # System shortcuts
      ".." = "cd ..";
      "..." = "cd ../..";

      # NixOS specific
      zc = "z ~/.config/claudeos";
      rebuild-test = "nh os test"; # flake path comes from NH_FLAKE (programs.nh.flake)
      flake-check = "nix flake check --flake ~/.config/claudeos";
    };

    # Fish abbreviations (expand as you type)
    shellAbbrs = {
      # Git abbreviations
      gs = "git status";
      gd = "git diff";
      gl = "git log --oneline --graph --decorate";
      gp = "git pull";
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

      # Open today's morning-desk dashboard; --refresh rebuilds it first
      today = ''
        if contains -- --refresh $argv
          echo "Rebuilding today's dashboard..."
          systemctl --user start claudeos-morning-desk
        end
        set -l desk ~/Desk/today/index.html
        if test -f $desk
          google-chrome-stable --app="file://$desk" &>/dev/null &
          disown
        else
          echo "No dashboard yet — run: today --refresh"
        end
      '';

      # Resume the last background agent session (self-heal, journal diary)
      # and authorize its proposed action. Session resume keeps full context —
      # the agent picks up exactly where it stopped.
      approve = ''
        set -l sid_file ~/.local/state/claudeos/last-agent-session
        if not test -r $sid_file
          echo "No pending agent session."
          return 1
        end
        pushd ~/.config/claudeos
        claude --resume (cat $sid_file) -p "User approved via the 'approve' command. Execute the action you proposed, then summarize what you did." --allowedTools "Read,Grep,Glob,Edit,Bash"
        popd
      '';

      # Rebuild NixOS with snapper pre/post snapshots + Claude-named generation
      # + auto-commit. Uses nh (build graph via nom, closure diff on activation).
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

        # Name this generation: claude-name-generation (claude-helpers.nix)
        # turns the pending diff into a haiku-written slug, falling back to
        # a timestamp. The slug becomes the boot-menu label
        # (system.nixos.tags) and the snapper snapshot description.
        set -l slug (begin
          git -C ~/.config/claudeos diff 2>/dev/null
          git -C ~/.config/claudeos diff --cached 2>/dev/null
        end | claude-name-generation --fallback "rebuild-"(date +%m%d-%H%M))
        git -C ~/.config/claudeos add generation-label
        echo "Generation label: $slug"

        set -l pre_root (sudo snapper -c root create --type pre --cleanup-algorithm number --print-number --description "pre: $slug" 2>/dev/null)
        set -l pre_home (snapper -c home create --type pre --cleanup-algorithm number --print-number --description "pre: $slug" 2>/dev/null)
        if test -n "$pre_root" -a -n "$pre_home"
          echo "Snapshots: root#$pre_root, home#$pre_home"
        else
          echo "Warning: snapper pre-snapshots failed (root#$pre_root, home#$pre_home)"
        end

        nh os switch -- $pass_args
        set -l rebuild_status $status

        if test $rebuild_status -eq 0
          if test -n "$pre_root"
            sudo snapper -c root create --type post --pre-number $pre_root --cleanup-algorithm number --description "post: $slug"
          end
          if test -n "$pre_home"
            snapper -c home create --type post --pre-number $pre_home --cleanup-algorithm number --description "post: $slug"
          end
          if test -n "$pre_root"
            echo "Rebuild complete. Rollback: sudo snapper -c root undochange $pre_root..(math $pre_root + 1)"
          else
            echo "Rebuild complete. (No snapshots for rollback)"
          end

          # Auto-commit config changes with Claude-generated message
          # (claude-commit in claude-helpers.nix)
          if not $no_commit
            claude-commit
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

      # GitHub token is NOT exported globally — use the `with-github-token`
      # wrapper (cli-tools.nix) to materialize it only in the consuming
      # process. gh's keyring stays the single source of truth.

      # UniFi MCP server credential — .mcp.json expands ''${UNIFI_API_KEY} from the
      # environment instead of hardcoding the key in a tracked file
      if test -r /run/secrets/unifi_api_key
        set -gx UNIFI_API_KEY (cat /run/secrets/unifi_api_key)
      end

      # Themed man pages via batman (bat-extras, uses Stylix terminal palette)

      # Daily brief on first shell (the one thing — no spec-sheet fetch above
      # it; macchina was dropped per the proactivity doctrine, and the full
      # dashboard lives in `today`)
      if not set -q CLAUDEOS_BRIEF_SHOWN
        set -gx CLAUDEOS_BRIEF_SHOWN 1
        set -l brief_file "$HOME/.cache/claudeos-monitor/daily-brief.txt"
        if test -s "$brief_file"
          cat "$brief_file"
        end
      end

      # Vi key bindings (disabled by default, uncomment to enable)
      # fish_vi_key_bindings
    '';
  };
}
