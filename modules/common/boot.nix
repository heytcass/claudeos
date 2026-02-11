{ lib, pkgs, ... }:

{
  # Use systemd-boot (modern, simple UEFI bootloader)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Keep last 5 generations to save space
  boot.loader.systemd-boot.configurationLimit = 5;

  # Enable Plymouth for prettier boot screens (optional)
  boot.plymouth.enable = lib.mkDefault false;

  # Silent boot
  boot.kernelParams = [ "quiet" "splash" ];

  # Latest kernel for best hardware support
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
}
