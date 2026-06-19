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

  # The LTS kernel cleared the early lock, but the 7280 then HARD-LOCKS (Caps
  # Lock dead) at the display handoff. i915 Panel Self-Refresh / display power
  # states are the classic Kaby Lake culprit there — disable them. Also drop
  # the shared "quiet" param during bring-up so a failed boot shows its last
  # kernel line (journald can't capture a hard lock). Restore quiet + re-test
  # PSR once boot is proven.
  boot.kernelParams = lib.mkForce [
    "i915.enable_psr=0"
    "i915.enable_dc=0"
    "i915.enable_fbc=0"
  ];

  # scx_lavd (BPF scheduler, modules/common/system.nix) can wedge the CPU hard
  # — indistinguishable from the i915 lock above (dead Caps Lock) — when its
  # service starts late in boot. Disable it on this host during bring-up to
  # remove the variable; re-enable once the desktop is confirmed stable.
  services.scx.enable = lib.mkForce false;

  # BRING-UP ONLY: boot.nix sets systemd-boot.editor = false, which blocks
  # editing the kernel cmdline at the boot menu — forcing a full USB rescue
  # cycle for every kernel-param experiment. Re-enable the editor here so we
  # can test params (nomodeset, individual i915 flags) live by pressing `e` at
  # the systemd-boot menu. SECURITY NOTE: this lets anyone at the keyboard pass
  # arbitrary kernel params (e.g. init=/bin/sh) — acceptable on a testbed mid
  # bring-up; REVERT (drop this line) once the machine boots reliably.
  boot.loader.systemd-boot.editor = lib.mkForce true;

  # TESTBED TRIAL (tool-rethink 2026-06-12): iwd as NetworkManager's wifi
  # backend — faster scans, better roaming, WPA3, while NM keeps the GNOME
  # integration. Graduates to modules/common/networking.nix if the trial
  # holds. Note: wifi passphrases are entered fresh (no wpa_supplicant
  # profile migration — fresh install anyway).
  networking.networkmanager.wifi.backend = "iwd";
}
