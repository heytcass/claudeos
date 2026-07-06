{ lib, pkgs, ... }:

let
  claudeLib = import ../../lib/claude-script.nix { inherit pkgs lib; };

  # Shared by both screenshot commands ($SCREENSHOT expands at runtime)
  screenshotPrompt = "Read the screenshot at $SCREENSHOT and describe what you see. Focus on any errors, issues, or things that need attention. Be brief and actionable.";
in
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

    # Claude Code quick-launch (bound to Super+C via GNOME custom keybinding)
    (pkgs.writeShellScriptBin "claude-quick" ''
      exec ghostty \
        --class=claude-quick \
        -e claude
    '')

    # Screenshot → Claude analysis (notification, bound to Super+Shift+A)
    (claudeLib.mkClaudeScriptBin {
      name = "claude-screenshot";
      runtimeInputs = [ pkgs.gnome-screenshot ];
      text = ''
        SCREENSHOT="/tmp/claudeos-screenshot-$$.png"
        gnome-screenshot -f "$SCREENSHOT"
        if [[ -x "$CLAUDE_BIN" ]]; then
          response=$("$CLAUDE_BIN" -p "${screenshotPrompt}" --allowedTools "Read" --model haiku 2>/dev/null)
          if [[ -n "$response" ]]; then
            claudeos_notify "Screen Analysis" "$response"
          else
            claudeos_notify "Screen Analysis" "Claude couldn't analyze the screenshot."
          fi
        fi
        rm -f "$SCREENSHOT"
      '';
    })

    # Screenshot → Claude analysis (interactive terminal, bound to Super+Ctrl+A)
    (claudeLib.mkClaudeScriptBin {
      name = "claude-screenshot-interactive";
      runtimeInputs = [
        pkgs.gnome-screenshot
        pkgs.ghostty
      ];
      text = ''
        SCREENSHOT="/tmp/claudeos-screenshot-$$.png"
        gnome-screenshot -f "$SCREENSHOT"
        claude_interactive "${screenshotPrompt}" "Read" --model sonnet
        rm -f "$SCREENSHOT"
      '';
    })

    # Claude-powered desktop search (bound to Super+A)
    (claudeLib.mkClaudeScriptBin {
      name = "claude-ask-desktop";
      runtimeInputs = [ pkgs.zenity ];
      text = ''
        query=$(zenity --entry --title "Ask Claude" --text "Ask Claude ❯" 2>/dev/null)
        [[ -z "$query" ]] && exit 0
        if [[ -x "$CLAUDE_BIN" ]]; then
          response=$("$CLAUDE_BIN" -p "$query" --model haiku 2>/dev/null)
          if [[ -n "$response" ]]; then
            claudeos_notify "Claude" "$response"
          fi
        fi
      '';
    })

    # Supabase CLI for Open Brain deployments
    supabase-cli

    # Nix development tools
    nixfmt
    statix
    deadnix
    nixd # Nix LSP — flake-aware (completes real NixOS/HM options); nil went unmaintained
    nvd # Closure diff between generations (standalone; nh diffs automatically)
    nix-output-monitor # Live build-graph visualization (nom)
  ];

  # envfs: FUSE filesystem on /bin and /usr/bin that resolves any interpreter
  # from the calling process's PATH (with sh/env static fallbacks). Replaces the
  # old hand-rolled /bin/bash activation symlink and fixes the whole class of
  # "works on Ubuntu, breaks on NixOS" third-party scripts (Claude plugin hooks).
  services.envfs.enable = true;

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

  # sched_ext: scx_lavd BPF scheduler (Rust, Steam Deck lineage) — tuned for
  # interactive latency on battery devices; --autopower flips performance/
  # powersave with AC state. Kernel falls back to EEVDF instantly if it dies.
  services.scx = {
    enable = true;
    scheduler = "scx_lavd";
    extraArgs = [ "--autopower" ];
  };

  # dbus-broker: the Fedora/Arch default bus implementation — faster under the
  # chatty desktop IPC of Niri + Noctalia/quickshell
  services.dbus.implementation = "broker";

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

      // fwupd-refresh.service runs as DynamicUser "fwupd-refresh" and cannot
      // answer interactive polkit auth, so its LVFS metadata refresh dies with
      // "Failed to obtain auth" (found 2026-07-05 on transporter; it also
      // trips the 15-min health check, which can each cost a claude -p call).
      // Allow fwupd actions for exactly that service user.
      // Upstream: https://github.com/NixOS/nixpkgs/issues/530906 — delete
      // this rule once the nixpkgs fwupd module ships its own fix.
      polkit.addRule(function(action, subject) {
        if (
          action.id.indexOf("org.freedesktop.fwupd.") === 0 &&
          subject.user === "fwupd-refresh"
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
