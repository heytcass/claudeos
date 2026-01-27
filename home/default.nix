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
}
