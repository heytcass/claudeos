{ pkgs, lib, ... }:

# VSCode chosen over Zed (Feb 2026) for Claude ecosystem compatibility:
# - Official Anthropic extension with checkpointing, diagnostics, Agent Skills
# - Zed's Claude Code integration is beta (ACP bridge by Zed, not Anthropic)
# - Zed pre-1.0 with stability issues; revisit when ACP matures or Anthropic adopts it
{
  programs.vscode = {
    enable = true;

    # Use default profile with current Home Manager options
    profiles.default = {
      # Extensions
      extensions = with pkgs.vscode-extensions; [
        # Nix development
        jnoortheen.nix-ide
        mkhl.direnv
        # nix-env-selector removed — direnv handles Nix environments

        # Markdown
        yzhang.markdown-all-in-one
        davidanson.vscode-markdownlint

        # YAML
        redhat.vscode-yaml

        # Note: Claude extension must be installed manually from VSCode marketplace
      ];

      # User settings
      # Theme, fonts, and colors are managed by Stylix (home/theme.nix)
      userSettings = {
        # Editor behavior
        "editor.fontLigatures" = true;
        "editor.formatOnSave" = true;
        "editor.minimap.enabled" = false;
        "editor.renderWhitespace" = "selection";
        "editor.rulers" = [
          80
          120
        ];

        # Files
        "files.autoSave" = "onFocusChange";
        "files.trimTrailingWhitespace" = true;
        "files.insertFinalNewline" = true;

        # Workbench
        "workbench.startupEditor" = "none";

        # Terminal
        "terminal.integrated.defaultProfile.linux" = "fish";

        # Nix
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nil";
        "nix.serverSettings" = {
          "nil" = {
            "formatting" = {
              "command" = [ "nixfmt" ];
            };
          };
        };

        # Direnv
        "direnv.restart.automatic" = true;

        # Git
        "git.autofetch" = true;
        "git.confirmSync" = false;
        "git.enableSmartCommit" = true;

        # Telemetry
        "telemetry.telemetryLevel" = "off";

        # Markdown
        "[markdown]" = {
          "editor.wordWrap" = "on";
          "editor.quickSuggestions" = false;
        };

        # YAML
        "yaml.schemas" = {
          "https://json.schemastore.org/github-workflow.json" = ".github/workflows/*.yaml";
        };
        "[yaml]" = {
          "editor.insertSpaces" = true;
          "editor.tabSize" = 2;
          "editor.autoIndent" = "advanced";
        };
      };

      # Keybindings
      keybindings = [
        {
          key = "ctrl+shift+t";
          command = "workbench.action.terminal.new";
        }
      ];
    };
  };

  # Remove stale backup files before home-manager's link phase so
  # backupFileExtension = "backup" doesn't fail on existing .backup files.
  home.activation.cleanVscodeBackups = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    for f in "$HOME/.config/Code/User/settings.json.backup" \
             "$HOME/.config/Code/User/keybindings.json.backup"; do
      [ -e "$f" ] && $DRY_RUN_CMD rm "$f"
    done
  '';

  # Replace immutable Nix store symlinks with writable copies so VSCode
  # and extensions can persist runtime settings changes without errors.
  home.activation.mutableVscodeFiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for f in "$HOME/.config/Code/User/settings.json" \
             "$HOME/.config/Code/User/keybindings.json"; do
      if [ -L "$f" ]; then
        target=$(readlink "$f")
        $DRY_RUN_CMD rm "$f"
        $DRY_RUN_CMD cp "$target" "$f"
        $DRY_RUN_CMD chmod u+w "$f"
      fi
    done
  '';
}
