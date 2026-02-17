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
  ];

  # Enable weekly auto-update by default (build-only, no auto-apply)
  claude-os.autoUpdate.enable = lib.mkDefault true;
}
