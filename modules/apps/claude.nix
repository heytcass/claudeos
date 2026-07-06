{
  lib,
  config,
  pkgs,
  inputs,
  user,
  ...
}:

{
  options.claude-os.claude.enable = lib.mkEnableOption "Claude Code CLI and Claude Desktop";

  config = lib.mkIf config.claude-os.claude.enable {

    # Claude Code CLI - Official tool with nix-ld for dynamic linking
    #
    # Uses nix-ld to provide dynamic library compatibility for the official
    # Claude Code CLI installer from Anthropic. This allows the tool to
    # auto-update itself and all plugins/skills without NixOS intervention.

    # Enable nix-ld for dynamic binary compatibility
    programs.nix-ld.enable = true;

    # Provide libraries that Claude Code (and Claude Desktop) need
    programs.nix-ld.libraries = with pkgs; [
      # Standard C/C++ runtime
      stdenv.cc.cc.lib

      # Core system libraries
      glibc

      # Common dependencies for Node/Electron-based CLIs
      openssl
      zlib
      curl

      # Additional libraries that might be needed
      libz
      icu
    ];

    # SSL certificate compatibility for non-Nix binaries (Claude Code, etc.)
    # The bundled Node.js/OpenSSL looks for /etc/ssl/cert.pem and individual
    # hash-linked certs in /etc/ssl/certs/. NixOS only provides the bundle
    # files, so we symlink cert.pem to the CA bundle to avoid failed lookups
    # that slow down every HTTPS connection.
    environment.etc."ssl/cert.pem".source = "/etc/ssl/certs/ca-certificates.crt";

    # Sandbox dependencies (bubblewrap is already pulled in by xdg-desktop-portal)
    environment.systemPackages = with pkgs; [ socat ];

    # PATH configuration for Claude Code CLI is in home/shell/fish.nix
    # (Adds ~/.local/bin to PATH where Claude Code installs itself)

    # ============================================================================
    # Claude Code CLI Automated Installation
    # ============================================================================

    # Systemd user service to automatically install Claude Code CLI on first login.
    # Only runs if ~/.local/bin/claude doesn't exist (idempotent).
    # After installation, Claude auto-updates itself without NixOS intervention.
    #
    # Hardened after the 2026-07-05 transporter reinstall, where it silently
    # failed twice over:
    #  - exit 127: user units get a minimal PATH, so bare `curl` wasn't found
    #    (fixed with `path = [...]`; install.sh also needs coreutils/tar/gzip)
    #  - first login raced Wi-Fi setup, so even with curl the download would
    #    have failed (fixed with a bounded wait-for-network loop — user units
    #    can't order after the system network-online.target)
    #  - ConditionUser keeps it out of gdm-greeter user managers (the
    #    jasper.nix greeter lesson; it was curl-ing into greeter homes)
    systemd.user.services.claude-code-installer = {
      description = "Install Claude Code CLI on first login";
      wantedBy = [ "default.target" ];
      path = with pkgs; [
        bash
        curl
        coreutils
        gnutar
        gzip
      ];

      # Only run if claude doesn't exist, and never for greeter/system users
      unitConfig = {
        ConditionPathExists = "!%h/.local/bin/claude";
        ConditionUser = user;
      };

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.writeShellScript "install-claude-code" ''
          set -euo pipefail
          # First login may race network setup — wait up to 5 minutes
          for i in $(seq 1 60); do
            curl -fsIm 5 https://claude.ai >/dev/null 2>&1 && break
            sleep 5
          done
          curl -fsSL https://claude.ai/install.sh | bash
        ''}";
      };
    };

    # ============================================================================
    # Claude Desktop (via claude-desktop-linux flake)
    # ============================================================================

    # The flake extracts the macOS DMG, patches the Electron app for Linux
    # (platform detection, tray icons, origin validation), and wraps with
    # nixpkgs electron. No insecure electron version needed.

    home-manager.users.${user} = {
      home.packages = [
        inputs.claude-desktop-linux.packages.${pkgs.system}.claude-desktop
      ];
    };

  }; # end config
}
