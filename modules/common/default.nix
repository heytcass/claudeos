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
    ./claude-helpers.nix
  ];

  # Weekly auto-update, fully autonomous: the VM smoke-test gate boots each
  # new generation in a throwaway QEMU VM before commit/push/switch. Without
  # usable KVM the run degrades to build-only (commit + push, never switch).
  claude-os.autoUpdate.enable = lib.mkDefault true;
  claude-os.autoUpdate.autoApply = lib.mkDefault true;

  # Watched units file their own fix PRs on failure
  claude-os.selfHeal.enable = lib.mkDefault true;
}
