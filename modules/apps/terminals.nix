{ config, lib, pkgs, ... }:

{
  # Install WezTerm terminal emulator
  environment.systemPackages = with pkgs; [
    wezterm
  ];

  # Set WezTerm as default terminal
  environment.sessionVariables = {
    TERMINAL = "wezterm";
  };

  # Create custom desktop file for WezTerm to handle terminal:// URLs
  environment.etc."xdg/applications/wezterm-default.desktop".text = ''
    [Desktop Entry]
    Name=WezTerm
    Comment=Terminal Emulator
    Exec=wezterm start
    Icon=org.wezfurlong.wezterm
    Type=Application
    Terminal=false
    Categories=System;TerminalEmulator;
    MimeType=x-scheme-handler/terminal;
  '';

  # WezTerm is the only terminal in launcher
  # gnome-console and xterm are hidden in modules/desktop/gnome.nix
}
