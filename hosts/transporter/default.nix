{ lib, pkgs, ... }:

{
  # Dell Latitude 7280 — TESTBED host for the ClaudeOS return.
  # Purpose: prove the integration story (Claude desktop app, Chrome extension
  # native messaging, VSCode, file pickers/drag-and-drop, MCP experimentation)
  # on real hardware before gti is reinstalled.
  #
  # First-install checklist (see docs/SECRETS.md for details):
  #   1. After install, derive this host's age key:
  #        nix shell nixpkgs#ssh-to-age -c ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
  #   2. Add it to .sops.yaml as &transporter_host and run
  #        sops updatekeys secrets/secrets.yaml
  #      Until then, sops secrets won't decrypt here (jasper will stay down).

  imports = [
    ./hardware-configuration.nix
  ];

  # Disko disk device for this machine (SATA SSD)
  disko.devices.disk.main.device = "/dev/sda";

  # The latest mainline kernel (modules/common/boot.nix default) HARD-LOCKS
  # this Latitude 7280 ~3 lines into early boot (Caps Lock dead = CPU freeze,
  # before userspace — classic latest-kernel regression on Kaby Lake). Pin the
  # stable LTS kernel; it's still ≥6.12, so scx_lavd's sched_ext support holds.
  # Overrides the mkDefault in boot.nix.
  boot.kernelPackages = pkgs.linuxPackages;

  # Drop the shared "quiet" param on this host while we're bringing it up, so a
  # failed boot shows its last kernel line on-screen (the persistent journal
  # can't capture a pre-userspace lock). Restore once boot is proven.
  boot.kernelParams = lib.mkForce [ ];

  # TESTBED TRIAL (tool-rethink 2026-06-12): iwd as NetworkManager's wifi
  # backend — faster scans, better roaming, WPA3, while NM keeps the GNOME
  # integration. Graduates to modules/common/networking.nix if the trial
  # holds. Note: wifi passphrases are entered fresh (no wpa_supplicant
  # profile migration — fresh install anyway).
  networking.networkmanager.wifi.backend = "iwd";
}
