{ lib, pkgs, ... }:

{
  # Use systemd-boot (modern, simple UEFI bootloader)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Include console fonts in the initrd so systemd-vconsole-setup can find them
  # before the NixOS activation script sets up /etc/kbd
  console.earlySetup = true;

  # Keep last 10 generations for rollback headroom (GC handles cleanup
  # independently). The initrd is small enough (~58MB with Plymouth, and
  # identical initrds dedup) that 10 generations fit comfortably in the 1G
  # ESP — and rollback depth is operational capacity for an agent-maintained
  # OS.
  boot.loader.systemd-boot.configurationLimit = 10;

  # Disable the boot-entry kernel cmdline editor — with an unencrypted disk it's
  # a trivial init=/bin/sh root shell for anyone with physical access
  boot.loader.systemd-boot.editor = false;

  # Plymouth lives in modules/desktop/plymouth.nix. It was kept out while it
  # cost ~60-90MB/generation under systemd-initrd; on the scripted initrd it
  # measured +7MB (51.0 → 58.1MB, 2026-10-27), which the ESP absorbs.

  # Silent boot; PSR disabled fleet-wide. Panel Self Refresh freezes the eDP
  # panel on both hosts' gen9 Intel displays when the screen goes fully static
  # — the greeter is the only such screen (no idle daemon, no clock in the
  # framebuffer), so it presented as "greetd locks up if you don't log in
  # within a couple minutes" (3 boots on transporter, 1 on gti, all silent in
  # the journal while logind kept answering the power key). gti's freeze was
  # nixos-hardware's kaby-lake profile forcing i915.enable_psr=2; transporter's
  # was the PSR1-on driver default. mkAfter sorts our param after the profile's,
  # and the kernel takes the last occurrence of a duplicated module param.
  boot.kernelParams = lib.mkMerge [
    [ "quiet" ]
    (lib.mkAfter [ "i915.enable_psr=0" ])
  ];

  # Latest kernel for best hardware support
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
}
