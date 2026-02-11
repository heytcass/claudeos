{ pkgs, ... }:

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

  # PATH configuration for Claude Code CLI is in home/shell/fish.nix
  # (Adds ~/.local/bin to PATH where Claude Code installs itself)

  # ============================================================================
  # Installation Instructions
  # ============================================================================

  # Claude Code CLI:
  # 1. After deploying this config, run the official installer:
  #    curl -fsSL https://claude.ai/install.sh | bash
  # 2. The installer will download Claude Code to ~/.local/bin/claude
  # 3. After deployment with the updated PATH, logout/login or run:
  #    source ~/.config/fish/config.fish
  # 4. Claude Code will be available as 'claude' command
  # 5. Auto-updates work seamlessly - Claude updates itself
  # 6. Shell integration (completions, hooks) works normally

  # Other Claude Interfaces (Manual Setup):
  #
  # Claude in Chrome Extension:
  # 1. Install Chrome browser (already included in browsers.nix)
  # 2. Visit Chrome Web Store: https://chromewebstore.google.com/detail/claude-in-chrome/
  # 3. Click "Add to Chrome" to install the extension
  # 4. Click the extension icon and sign in with your Claude account
  # 5. Grant necessary permissions for browser automation
  # 6. The extension will work with claude.ai website for browser automation
  # Note: Cannot be installed declaratively via NixOS
  #
  # VSCode Claude Extension:
  # 1. VSCode is already installed (see development/vscode.nix)
  # 2. Open VSCode and go to Extensions (Ctrl+Shift+X)
  # 3. Search for "Claude" or "Anthropic"
  # 4. Install the official Claude extension
  # 5. Click "Sign in with Claude" in the extension
  # 6. Complete browser-based OAuth authentication
  # 7. Extension will be available in VSCode sidebar
  # Note: VSCode extensions cannot be declaratively managed in current home-manager
  #       (extensions are only supported for VSCodium, not VSCode)
  #
  # Claude Desktop:
  # - No official Linux support from Anthropic
  # - Third-party flakes exist but are fragile (extract from macOS builds)
  # - Not included in this configuration due to stability concerns
  # - If needed, can be manually installed from community sources
}
