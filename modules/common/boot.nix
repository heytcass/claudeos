{ lib, pkgs, ... }:

{
  # Use systemd-boot (modern, simple UEFI bootloader)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Keep last 10 generations for rollback headroom (GC handles cleanup independently)
  boot.loader.systemd-boot.configurationLimit = 10;

  # Plymouth boot splash (themed automatically by Stylix)
  boot.plymouth.enable = lib.mkDefault true;

  # Use Claude logo for Plymouth boot screen
  stylix.targets.plymouth = {
    logo = ../../assets/claude-logo.png;
    logoAnimated = true; # Spinning animation (logo has rotational symmetry)
  };

  # Silent boot
  boot.kernelParams = [
    "quiet"
    "splash"
  ];

  # Latest kernel for best hardware support
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
}
