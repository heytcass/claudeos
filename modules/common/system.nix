{ lib, pkgs, ... }:

{
  # Essential system packages available to all users
  environment.systemPackages = with pkgs; [
    # Basic utilities
    vim
    micro # Modern terminal text editor
    wget
    curl
    gh # GitHub CLI
    htop
    tree
    file
    unzip
    zip
    pciutils
    usbutils

    # Network tools
    dig
    nmap
    traceroute

    # Build essentials (for some apps)
    gcc
    gnumake
  ];

  # Enable NTFS support
  boot.supportedFilesystems = [ "ntfs" ];

  # Enable firmware updates
  services.fwupd.enable = true;

  # Enable thermald for Intel CPU thermal management
  services.thermald.enable = lib.mkDefault true;

  # Zram swap for compressed in-memory swap
  zramSwap.enable = true;

  # Periodic btrfs scrub to detect and repair data corruption
  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = [ "/" ];
  };
}
