{ lib, ... }:

let
  themeLib = import ../lib/theme.nix;
in
{
  programs.ghostty = {
    enable = true;

    # Ghostty configuration
    # Colors are managed by Stylix - see modules/desktop/theme.nix
    settings = {
      # Font fallback order — overrides Stylix which puts Noto Color Emoji
      # before the Nerd Font, causing symbol codepoints (U+23F8, U+273B)
      # to render as oversized color emoji instead of monochrome glyphs.
      font-family = lib.mkForce [
        themeLib.fonts.monospace.nerdName # Primary: monospace + Nerd Font symbols
        themeLib.fonts.symbols.name # Nerd Font private-use-area icons
        themeLib.fonts.symbols.fallback # Monochrome glyphs (⏸ U+23F8, ✻ U+273B, etc.)
        themeLib.fonts.emoji.name # Fallback: actual emoji only
      ];
      font-size = 11;

      # Cursor
      cursor-style = "block";
      cursor-style-blink = false;

      # Window configuration
      window-padding-x = 8;
      window-padding-y = 8;
      window-decoration = true; # Use native GTK decorations

      # GTK/libadwaita integration
      gtk-titlebar = true;
      # Tab bar uses Adwaita symbolic icons (adwaita-icon-theme + hicolor shim in modules/desktop/default.nix)
      # Default behavior: show tab bar when multiple tabs are open

      # Performance and platform integration
      # Note: Ghostty automatically uses Wayland when available, no config needed
      linux-cgroup = "always";

      # Shell integration
      shell-integration = "fish";
      shell-integration-features = "cursor,sudo,title";

      # Scrollback
      scrollback-limit = 50000;

      # Mouse integration
      copy-on-select = true; # Auto-copy selection to clipboard
      mouse-hide-while-typing = true;

      # Window behavior
      window-save-state = "always"; # Remember window size/position
      window-inherit-working-directory = true;
      window-inherit-font-size = true;

      # Close without confirmation
      quit-after-last-window-closed = true;
      confirm-close-surface = false;

      # Key bindings — Ghostty defaults are fine (Ctrl+Shift+T/W/C/V)
    };
  };

}
