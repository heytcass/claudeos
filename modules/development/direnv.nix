{ pkgs, ... }:

{
  # Enable direnv system-wide
  programs.direnv = {
    enable = true;

    # Enable nix-direnv for better flake support and caching
    nix-direnv.enable = true;
  };

  # Install direnv package
  environment.systemPackages = with pkgs; [
    direnv
    nix-direnv
  ];

  # Note: Fish shell integration is configured in home/shell/cli-tools.nix
  # This module just enables direnv system-wide

  # direnv allows per-project .envrc files to automatically load
  # Nix environments when entering directories
  # Example .envrc: use flake
}
