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

  # Keep last 5 generations for rollback headroom (GC handles cleanup independently).
  # Each generation copies kernel+initrd (~60-90MB with plymouth) to the ESP,
  # so 10 generations of distinct kernels can overflow even a 1G partition.
  boot.loader.systemd-boot.configurationLimit = 5;

  # Disable the boot-entry kernel cmdline editor — with an unencrypted disk it's
  # a trivial init=/bin/sh root shell for anyone with physical access
  boot.loader.systemd-boot.editor = false;

  # Plymouth boot splash (themed automatically by Stylix)
  boot.plymouth.enable = lib.mkDefault true;

  # Use Claude logo for Plymouth boot screen
  stylix.targets.plymouth = {
    logo = ../../assets/claude-logo.png;
    logoAnimated = false;
  };

  # Silent boot
  boot.kernelParams = [
    "quiet"
    "splash"
  ];

  # Latest kernel for best hardware support
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
}
