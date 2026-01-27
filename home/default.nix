{ config, pkgs, ... }:

{
  # Import all Home Manager modules
  imports = [
    ./shell
    ./wezterm.nix
    ./git.nix
    ./vscode.nix
  ];

  # This is required for home-manager
  home.stateVersion = "24.11";

  # Basic home configuration
  home.username = "tom";
  home.homeDirectory = "/home/tom";

  # Let home-manager manage itself
  programs.home-manager.enable = true;

  # Hide CLI tools from application launcher
  # These are useful utilities but shouldn't clutter the app menu
  xdg.dataFile."applications/vim.desktop".text = ''
    [Desktop Entry]
    Hidden=true
  '';
  xdg.dataFile."applications/htop.desktop".text = ''
    [Desktop Entry]
    Hidden=true
  '';
  xdg.dataFile."applications/micro.desktop".text = ''
    [Desktop Entry]
    Hidden=true
  '';
  xdg.dataFile."applications/yazi.desktop".text = ''
    [Desktop Entry]
    Hidden=true
  '';
  xdg.dataFile."applications/xterm.desktop".text = ''
    [Desktop Entry]
    Hidden=true
  '';
  xdg.dataFile."applications/uxterm.desktop".text = ''
    [Desktop Entry]
    Hidden=true
  '';
}
