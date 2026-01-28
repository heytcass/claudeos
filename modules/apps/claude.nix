{ config, lib, pkgs, inputs, ... }:

{
  # Claude Tools: CLI + Desktop
  #
  # Two different approaches for two different tools:
  #
  # 1. Claude Code CLI (nix-ld) - Official Linux binary, auto-updates
  # 2. Claude Desktop (flake) - Unofficial Linux port from macOS, requires maintenance

  # ============================================================================
  # Claude Code CLI - Official tool with nix-ld for dynamic linking
  # ============================================================================

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

  # Add ~/.claude/bin to PATH for Claude Code CLI
  home-manager.users.tom = {
    home.sessionPath = [
      "$HOME/.claude/bin"
    ];
  };

  # ============================================================================
  # Claude Desktop - Unofficial Linux port via flake
  # ============================================================================

  # Install Claude Desktop from the unofficial flake
  # WARNING: This is an unofficial port that extracts from macOS builds
  # and may break when Anthropic updates their desktop app
  #
  # Using FHS variant to enable MCP server support
  # This allows Claude Desktop to run MCP servers via npx, uvx, or Docker
  environment.systemPackages = [
    inputs.claude-desktop.packages.${pkgs.system}.claude-desktop-with-fhs
  ];

  # ============================================================================
  # Installation Instructions
  # ============================================================================

  # Claude Code CLI:
  # 1. After deploying this config, run the official installer:
  #    curl -fsSL https://claude.ai/install.sh | bash
  # 2. The installer will download Claude Code to ~/.claude/
  # 3. Claude Code will be available as 'claude' command
  # 4. Auto-updates work seamlessly - Claude updates itself in ~/.claude/
  # 5. Shell integration (completions, hooks) works normally

  # Claude Desktop:
  # 1. Launch from application menu or run: claude-desktop
  # 2. Sign in with your Claude account (browser-based OAuth)
  # 3. System tray icon, keyboard shortcuts, and desktop integration work
  # 4. MCP (Model Context Protocol) server support for local tools
  # 5. Configure MCP servers in: ~/.config/Claude/claude_desktop_config.json
  # 6. Updates require rebuilding NixOS config (flake input must be updated)
  # 7. May break when Anthropic updates their macOS builds

  # Claude in Chrome Extension (Manual Setup):
  # 1. Install Chrome browser (already included in browsers.nix)
  # 2. Visit Chrome Web Store: https://chromewebstore.google.com/detail/claude-in-chrome/
  # 3. Click "Add to Chrome" to install the extension
  # 4. Click the extension icon and sign in with your Claude account
  # 5. Grant necessary permissions for browser automation
  # 6. The extension will work with claude.ai website for browser automation
  # Note: Cannot be installed declaratively via NixOS

  # VSCode Claude Extension (Manual Setup):
  # 1. VSCode is already installed (see development/vscode.nix)
  # 2. Open VSCode and go to Extensions (Ctrl+Shift+X)
  # 3. Search for "Claude" or "Anthropic"
  # 4. Install the official Claude extension
  # 5. Click "Sign in with Claude" in the extension
  # 6. Complete browser-based OAuth authentication
  # 7. Extension will be available in VSCode sidebar
  # Note: VSCode extensions cannot be declaratively managed in current home-manager
  #       (extensions are only supported for VSCodium, not VSCode)

  # ============================================================================
  # Why Different Approaches?
  # ============================================================================

  # Claude Code CLI (nix-ld):
  # - Official Linux binary from Anthropic
  # - Auto-updates itself and all plugins/skills
  # - No maintenance burden
  # - Simple: just enable nix-ld and run installer

  # Claude Desktop (flake):
  # - No official Linux support from Anthropic
  # - Unofficial port extracts from macOS, replaces native bindings
  # - Requires manual maintenance when upstream changes
  # - But provides essential features: MCP servers, tray icon, system integration
  # - Worth the maintenance for those who use these features
}
