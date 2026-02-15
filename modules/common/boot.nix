{ lib, pkgs, ... }:

{
  # Use systemd-boot (modern, simple UEFI bootloader)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use systemd-based initrd for faster boot, better error handling,
  # and dependency-ordered service startup during early boot
  boot.initrd.systemd.enable = true;

  # Provide the Terminus font for the virtual console (required by systemd-based initrd —
  # systemd-vconsole-setup runs before the full filesystem is mounted)
  console.packages = [ pkgs.terminus_font ];

  # Keep last 10 generations for rollback headroom (GC handles cleanup independently)
  boot.loader.systemd-boot.configurationLimit = 10;

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
