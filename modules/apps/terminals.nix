{ config, lib, pkgs, ... }:

{
  # Install WezTerm terminal emulator
  environment.systemPackages = with pkgs; [
    wezterm
  ];

  # WezTerm is the only terminal in launcher
  # gnome-console and xterm are already excluded in modules/desktop/gnome.nix
}
