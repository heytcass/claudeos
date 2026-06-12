{ lib, pkgs, ... }:

{
  # Use systemd-boot (modern, simple UEFI bootloader)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use systemd-based initrd for faster boot, better error handling,
  # and dependency-ordered service startup during early boot
  boot.initrd.systemd.enable = true;

  # Include console fonts in the initrd so systemd-vconsole-setup can find them
  # before the NixOS activation script sets up /etc/kbd
  console.earlySetup = true;

  # Keep last 10 generations for rollback headroom (GC handles cleanup
  # independently). Without Plymouth the initrd is small enough that 10
  # generations fit comfortably in the 1G ESP — and rollback depth is
  # operational capacity for an agent-maintained OS.
  boot.loader.systemd-boot.configurationLimit = 10;

  # Disable the boot-entry kernel cmdline editor — with an unencrypted disk it's
  # a trivial init=/bin/sh root shell for anyone with physical access
  boot.loader.systemd-boot.editor = false;

  # No Plymouth: it pulled DRM drivers + firmware into every initrd
  # (~60-90MB/generation on the ESP) — trading rollback depth for a splash
  # screen on a machine that boots in seconds via systemd-initrd

  # Silent boot
  boot.kernelParams = [ "quiet" ];

  # Latest kernel for best hardware support
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
}
