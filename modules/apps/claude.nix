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

    # The claude-for-linux flake's pre-built packages use their own pkgs instance
    # (nixpkgs.legacyPackages) which ignores NixOS permittedInsecurePackages.
    # We work around this by using just the app.asar from the flake and wrapping
    # it with electron from the system pkgs (which respects our config).
    nixpkgs.config.permittedInsecurePackages = [ "electron-37.10.3" ];

    home-manager.users.${user} = {
      home.packages =
        let
          claudeApp = inputs.claude-for-linux.packages.${pkgs.system}.claude-app;

          claudeDesktop = pkgs.symlinkJoin {
            name = "claude-desktop";
            paths = [ claudeApp ];
            nativeBuildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              mkdir -p $out/bin
              makeWrapper ${pkgs.electron_37}/bin/electron $out/bin/claude-desktop \
                --add-flags "$out/lib/claude-desktop/app.asar" \
                --add-flags "--no-sandbox" \
                --add-flags "--ozone-platform-hint=auto" \
                --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.bubblewrap ]} \
                --set BWRAP_PATH "${pkgs.bubblewrap}/bin/bwrap"
            '';
          };

          claudeDesktopFHS = pkgs.buildFHSEnv {
            name = "claude-desktop";
            targetPkgs =
              pkgs: with pkgs; [
                bubblewrap
                nodejs
                glibc
                openssl
                coreutils
                bash
                git
                curl
              ];
            runScript = "${claudeDesktop}/bin/claude-desktop";
          };
        in
        [
          claudeDesktopFHS
          pkgs.bubblewrap
        ];

      xdg.desktopEntries.claude-desktop = {
        name = "Claude";
        genericName = "AI Assistant";
        exec = "claude-desktop %U";
        icon = "claude";
        categories = [
          "Development"
          "Utility"
        ];
        comment = "Claude Desktop with Linux Cowork support";
        mimeType = [ "x-scheme-handler/claude" ];
        settings.StartupWMClass = "Claude";
      };
    };

  }; # end config
}
