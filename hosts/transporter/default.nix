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

  # Kernel history on this Latitude 7280 (Kaby Lake, 2017):
  #   - linuxPackages_latest (7.0.x): HARD-LOCKS ~3 lines into early boot.
  #   - linuxPackages "LTS" (= 6.18.x in the current pin!): clears the early
  #     lock but HARD-LOCKS at the i915 display handoff, even with PSR/DC/FBC
  #     disabled.
  # The previous pin *claimed* conservatism but 6.18 is barely older than 7.0.
  # Pin the genuinely battle-tested 6.12 LTS (supported upstream to Dec 2026,
  # still ≥6.12 so sched_ext/scx_lavd support holds when re-enabled).
  boot.kernelPackages = pkgs.linuxPackages_6_12;

  # The nixos-hardware dell-latitude-7280 profile loads i915 in the STAGE-1
  # INITRD (early KMS) — so the display-handoff lock happens before root is
  # mounted and before journald exists, which is why no failed boot has left
  # evidence. Defer i915 to stage 2: the handoff then happens with the journal
  # on disk (a lock there leaves a log), and everything before it stays visible
  # on the EFI framebuffer. Boot cost is a later modeset flicker — irrelevant
  # during bring-up. Re-enable once boot is proven.
  hardware.intelgpu.loadInInitrd = false;

  # i915 Panel Self-Refresh / display power states / framebuffer compression
  # are the classic Kaby Lake hang culprits — keep them off until boot is
  # proven, then re-test one at a time. "quiet" (shared boot.nix param) stays
  # dropped during bring-up so a failed boot shows its last kernel line.
  # sysrq_always_enabled makes Magic SysRq work from earliest boot (the
  # kernel.sysrq sysctl only applies in stage 2): if the machine "locks",
  # Alt+PrtSc+B rebooting it proves the kernel is alive and the panel merely
  # went dark (display bug), while no reaction confirms a true CPU hard lock.
  # Restore quiet + drop sysrq_always_enabled once boot is proven.
  boot.kernelParams = lib.mkForce [
    "i915.enable_psr=0"
    "i915.enable_dc=0"
    "i915.enable_fbc=0"
    "sysrq_always_enabled=1"
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
