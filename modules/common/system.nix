{ lib, pkgs, ... }:

{
  # Essential system packages available to all users
  environment.systemPackages = with pkgs; [
    # Basic utilities
    vim
    micro # Modern terminal text editor
    wget
    curl
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

    # Claude Code quick-launch (bound to Mod+C via Niri keybinding)
    (pkgs.writeShellScriptBin "claude-quick" ''
      exec ghostty \
        --class=claude-quick \
        -e claude
    '')

    # Screenshot → Claude analysis (notification, bound to Mod+Shift+A)
    (pkgs.writeShellScriptBin "claude-screenshot" ''
      SCREENSHOT="/tmp/claudeos-screenshot-$$.png"
      ${pkgs.grim}/bin/grim "$SCREENSHOT"
      CLAUDE_BIN="$HOME/.local/bin/claude"
      if [[ -x "$CLAUDE_BIN" ]]; then
        response=$("$CLAUDE_BIN" -p "Read the screenshot at $SCREENSHOT and describe what you see. Focus on any errors, issues, or things that need attention. Be brief and actionable." --allowedTools "Read" --model haiku 2>/dev/null)
        if [[ -n "$response" ]]; then
          ${pkgs.libnotify}/bin/notify-send --app-name=ClaudeOS "Screen Analysis" "$response"
        else
          ${pkgs.libnotify}/bin/notify-send --app-name=ClaudeOS "Screen Analysis" "Claude couldn't analyze the screenshot."
        fi
      fi
      rm -f "$SCREENSHOT"
    '')

    # Screenshot → Claude analysis (interactive terminal, bound to Mod+Ctrl+A)
    (pkgs.writeShellScriptBin "claude-screenshot-interactive" ''
      SCREENSHOT="/tmp/claudeos-screenshot-$$.png"
      ${pkgs.grim}/bin/grim "$SCREENSHOT"
      ghostty --class=claude-quick -e bash -c "
        claude -p \"Read the screenshot at $SCREENSHOT and tell me what you see. Focus on any errors, issues, or things that need attention. Be brief and actionable.\" --allowedTools \"Read\" --model sonnet
        echo
        echo \"Press Enter to close...\"
        read
        rm -f \"$SCREENSHOT\"
      "
    '')

    # Claude-powered desktop search (bound to Mod+A)
    (pkgs.writeShellScriptBin "claude-ask-desktop" ''
      query=$(${pkgs.fuzzel}/bin/fuzzel --dmenu --prompt "Ask Claude ❯ ")
      [[ -z "$query" ]] && exit 0
      CLAUDE_BIN="$HOME/.local/bin/claude"
      if [[ -x "$CLAUDE_BIN" ]]; then
        response=$("$CLAUDE_BIN" -p "$query" --model haiku 2>/dev/null)
        if [[ -n "$response" ]]; then
          ${pkgs.libnotify}/bin/notify-send --app-name=ClaudeOS "Claude" "$response"
        fi
      fi
    '')

    # Supabase CLI for Open Brain deployments
    supabase-cli

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

  # Hardware video acceleration (Intel VA-API)
  # Reduces CPU load during video playback and extends battery life on laptops
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [ intel-media-driver ];
  };

  # Enable firmware updates
  services.fwupd.enable = true;

  # Enable thermald for Intel CPU thermal management
  services.thermald.enable = lib.mkDefault true;

  # Dynamic power profiles for laptops (balanced/power-saver/performance)
  # Works alongside thermald — thermald manages thermal limits, this manages power policy
  services.power-profiles-daemon.enable = lib.mkDefault true;

  # UPower: D-Bus service for battery/power source reporting
  # Required for Noctalia's Battery widget (and any other desktop battery indicators)
  services.upower.enable = true;

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

  # Polkit — allow wheel group to start/stop/restart systemd units without
  # repeated password prompts. Deliberately excludes manage-unit-files:
  # creating/enabling NEW root units stays behind authentication, so a
  # compromised user process can't silently install a root service.
  security.polkit = {
    enable = true;
    extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (
          action.id == "org.freedesktop.systemd1.manage-units" &&
          subject.isInGroup("wheel")
        ) {
          return polkit.Result.YES;
        }
      });
    '';
  };

  # Audit logging — forensic trail for security-relevant system events
  security.auditd.enable = true;
  security.audit = {
    enable = true;
    rules = [
      # Log time changes (potential indicator of log tampering)
      "-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change"

      # Log modifications to user/group databases
      "-w /etc/passwd -p wa -k identity"
      "-w /etc/group -p wa -k identity"
      "-w /etc/shadow -p wa -k identity"
    ];
  };

  # Periodic btrfs scrub to detect and repair data corruption
  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = [ "/" ];
  };

  # Weekly TRIM for any non-btrfs filesystems (e.g. the vfat ESP);
  # btrfs already trims continuously via discard=async in disko mount options
  services.fstrim.enable = true;
}
