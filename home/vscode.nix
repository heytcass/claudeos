{ pkgs, lib, ... }:

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
        arrterian.nix-env-selector

        # Markdown
        yzhang.markdown-all-in-one
        davidanson.vscode-markdownlint

        # YAML
        redhat.vscode-yaml

        # Note: Claude extension must be installed manually from VSCode marketplace
        # Search for "Claude Dev" by Saoud Rizwan in VSCode extensions
      ];

      # User settings
      userSettings = {
        # Editor settings
        # Use lib.mkForce to override Stylix's settings
        "editor.fontFamily" = lib.mkForce "'JetBrains Mono', 'Droid Sans Mono', 'monospace'";
        "editor.fontSize" = lib.mkForce 13;
        "editor.fontLigatures" = lib.mkForce true;
        "editor.formatOnSave" = true;
        "editor.minimap.enabled" = false;
        "editor.renderWhitespace" = "selection";
        "editor.rulers" = [ 80 120 ];

        # Files settings
        "files.autoSave" = "onFocusChange";
        "files.trimTrailingWhitespace" = true;
        "files.insertFinalNewline" = true;

        # Workbench settings
        # Override Stylix theme with our preferred settings
        "workbench.colorTheme" = lib.mkForce "Default Dark+";
        "workbench.iconTheme" = lib.mkForce "vs-minimal";
        "workbench.startupEditor" = "none";

        # Terminal settings
        "terminal.integrated.defaultProfile.linux" = "fish";
        "terminal.integrated.fontFamily" = lib.mkForce "'JetBrains Mono Nerd Font'";
        "terminal.integrated.fontSize" = lib.mkForce 12;

        # Nix settings
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nil";
        "nix.serverSettings" = {
          "nil" = {
            "formatting" = {
              "command" = [ "nixpkgs-fmt" ];
            };
          };
        };

        # Direnv settings
        "direnv.restart.automatic" = true;

        # Git settings
        "git.autofetch" = true;
        "git.confirmSync" = false;
        "git.enableSmartCommit" = true;

        # Telemetry
        "telemetry.telemetryLevel" = "off";

        # Markdown settings
        "markdown.preview.fontSize" = lib.mkForce 14;
        "markdown.preview.lineHeight" = lib.mkForce 1.6;
        "[markdown]" = {
          "editor.wordWrap" = "on";
          "editor.quickSuggestions" = false;
        };

        # YAML settings
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
}
