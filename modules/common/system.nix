{ config, lib, pkgs, ... }:

{
  # Essential system packages available to all users
  environment.systemPackages = with pkgs; [
    # Basic utilities
    vim
    micro     # Modern terminal text editor
    wget
    curl
    git
    gh        # GitHub CLI
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
}
