{ pkgs, ... }:

{
  # Install Ghostty terminal emulator
  environment.systemPackages = with pkgs; [
    ghostty
  ];

  # Set Ghostty as default terminal
  environment.sessionVariables = {
    TERMINAL = "ghostty";
  };

  # Create custom desktop file for Ghostty to handle terminal:// URLs
  environment.etc."xdg/applications/ghostty-default.desktop".text = ''
    [Desktop Entry]
    Name=Ghostty
    Comment=Terminal Emulator
    Exec=ghostty
    Icon=com.mitchellh.ghostty
    Type=Application
    Terminal=false
    Categories=System;TerminalEmulator;
    MimeType=x-scheme-handler/terminal;
  '';

  # Ghostty is the only terminal in launcher
  # gnome-console and xterm are hidden in modules/desktop/gnome.nix
}
