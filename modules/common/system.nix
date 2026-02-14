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
    nixfmt
    statix
    deadnix
    nil # Nix LSP
  ];

  # Many third-party scripts assume /bin/bash exists (e.g. Claude Code plugin hooks)
  system.activationScripts.binbash = ''
    mkdir -p /bin
    ln -sfn ${pkgs.bash}/bin/bash /bin/bash
  '';

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

  # Kernel security hardening
  boot.kernel.sysctl = {
    "kernel.sysrq" = 1; # Magic SysRq keys for emergency recovery (REISUB)
    "kernel.kptr_restrict" = 2; # Hide kernel pointers in /proc
    "kernel.dmesg_restrict" = 1; # Restrict dmesg to root
    "net.core.bpf_jit_harden" = 2; # Harden BPF JIT compiler
    "kernel.unprivileged_bpf_disabled" = 1; # Restrict BPF to root
    "net.ipv4.conf.all.rp_filter" = 1; # Reverse path filtering (anti-spoofing)
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.conf.all.send_redirects" = 0; # Don't send ICMP redirects
    "net.ipv4.conf.default.send_redirects" = 0;
  };

  # Periodic btrfs scrub to detect and repair data corruption
  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = [ "/" ];
  };
}
