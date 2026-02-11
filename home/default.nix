{ config, pkgs, ... }:

{
  # Phase 3: Home Manager configuration
  # For now, minimal setup

  # This is required for home-manager
  home.stateVersion = "24.11";

  # Basic home configuration
  home.username = "tom";
  home.homeDirectory = "/home/tom";

  # Let home-manager manage itself
  programs.home-manager.enable = true;

  # Imports will be added in Phase 3
  # imports = [
  #   ./shell
  #   ./git.nix
  #   ./wezterm.nix
  #   ./vscode.nix
  # ];

  # Phase 3: Add this useful alias for rebuilding system
  # programs.fish.shellAliases = {
  #   nixos-rebuild-switch = "sudo nixos-rebuild switch --flake ~/.config/claudeos#(hostname)";
  # };
}
