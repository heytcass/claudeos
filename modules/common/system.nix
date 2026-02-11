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
    traceroute

    # Nix development tools
    nixpkgs-fmt
    statix
    deadnix
    nil # Nix LSP
  ];

  # Enable redistributable firmware (includes CPU microcode)
  hardware.enableRedistributableFirmware = true;

  # Enable firmware updates
  services.fwupd.enable = true;

  # Enable thermald for Intel CPU thermal management
  services.thermald.enable = lib.mkDefault true;

  # Zram swap for compressed in-memory swap
  zramSwap.enable = true;

  # systemd-oomd: proactive OOM handling using PSI (Pressure Stall Information)
  # Kills memory-hogging processes before the kernel OOM killer freezes the system
  systemd.oomd = {
    enable = true;
    enableRootSlice = true;
    enableUserSlices = true;
    enableSystemSlice = true;
  };

  # Mount /tmp as tmpfs (RAM-backed, auto-cleaned on reboot)
  boot.tmp.useTmpfs = true;

  # Enable magic SysRq keys for emergency recovery (REISUB)
  boot.kernel.sysctl."kernel.sysrq" = 1;


  # Periodic btrfs scrub to detect and repair data corruption
  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = [ "/" ];
  };
}
