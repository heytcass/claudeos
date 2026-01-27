{ config, lib, pkgs, ... }:

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

        # Note: Claude extension must be installed manually from VSCode marketplace
        # Search for "Claude Dev" by Saoud Rizwan in VSCode extensions
      ];

      # User settings
      userSettings = {
        # Editor settings
        "editor.fontFamily" = "'JetBrains Mono', 'Droid Sans Mono', 'monospace'";
        "editor.fontSize" = 13;
        "editor.fontLigatures" = true;
        "editor.formatOnSave" = true;
        "editor.minimap.enabled" = false;
        "editor.renderWhitespace" = "selection";
        "editor.rulers" = [ 80 120 ];

        # Files settings
        "files.autoSave" = "onFocusChange";
        "files.trimTrailingWhitespace" = true;
        "files.insertFinalNewline" = true;

        # Workbench settings
        "workbench.colorTheme" = "Default Dark+";
        "workbench.iconTheme" = "vs-minimal";
        "workbench.startupEditor" = "none";

        # Terminal settings
        "terminal.integrated.defaultProfile.linux" = "fish";
        "terminal.integrated.fontFamily" = "'JetBrains Mono Nerd Font'";
        "terminal.integrated.fontSize" = 12;

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
