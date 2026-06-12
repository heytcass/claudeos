{ lib, ... }:

{
  imports = [
    ./boot.nix
    ./disko.nix
    ./nix.nix
    ./users.nix
    ./networking.nix
    ./locale.nix
    ./system.nix
    ./secrets.nix
    ./snapshots.nix
    ./auto-update.nix
    ./generation-label.nix
    ./self-heal.nix
  ];

  # Enable weekly auto-update by default (build-only, no auto-apply)
  claude-os.autoUpdate.enable = lib.mkDefault true;

  # Watched units file their own fix PRs on failure
  claude-os.selfHeal.enable = lib.mkDefault true;
}
