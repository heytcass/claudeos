{ pkgs, inputs, user, ... }:

{
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

  # PATH configuration for Claude Code CLI is in home/shell/fish.nix
  # (Adds ~/.local/bin to PATH where Claude Code installs itself)

  # ============================================================================
  # Claude Code CLI Automated Installation
  # ============================================================================

  # Systemd user service to automatically install Claude Code CLI on first login.
  # Only runs if ~/.local/bin/claude doesn't exist (idempotent).
  # After installation, Claude auto-updates itself without NixOS intervention.
  systemd.user.services.claude-code-installer = {
    description = "Install Claude Code CLI on first login";
    wantedBy = [ "default.target" ];

    # Only run if claude doesn't exist
    unitConfig.ConditionPathExists = "!%h/.local/bin/claude";

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -c 'curl -fsSL https://claude.ai/install.sh | bash'";
    };
  };

  # ============================================================================
  # Claude Desktop (via claude-for-linux flake)
  # ============================================================================

  # Import and configure claude-for-linux Home Manager module
  home-manager.users.${user} = {
    imports = [ inputs.claude-for-linux.homeManagerModules.x86_64-linux.default ];

    programs.claude-cowork = {
      enable = true;
      installPatches = true;
      createDesktopEntry = true;
    };
  };
}
