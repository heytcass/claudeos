{ lib, ... }:

{
  programs.ghostty = {
    enable = true;

    # Ghostty configuration
    # Colors are managed by Stylix - see modules/desktop/theme.nix
    settings = {
      # Font configuration
      # Use mkForce to override Stylix's font-family list, which puts
      # Noto Color Emoji before the Nerd Font — causing symbol codepoints
      # (pause icon, star glyphs) to render as color emoji instead of
      # monochrome terminal glyphs from the Nerd Font.
      font-family = lib.mkForce [
        "JetBrains Mono Nerd Font" # Primary: monospace + Nerd Font symbols
        "Symbols Nerd Font" # Nerd Font private-use-area icons
        "Noto Sans Symbols 2" # Monochrome glyphs for standard codepoints
        # (⏸ U+23F8, ✻ U+273B, etc.) — prevents
        # color emoji from overriding terminal colors
        "Noto Color Emoji" # Fallback: actual emoji only
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
      # Tab bar uses Adwaita symbolic icons (adwaita-icon-theme-legacy in cosmic-system.nix)
      # Default behavior: show tab bar when multiple tabs are open

      # Performance and platform integration
      # Note: Ghostty automatically uses Wayland when available, no config needed
      linux-cgroup = "always";

      # Shell integration
      shell-integration = "fish";
      shell-integration-features = "cursor,sudo,title";

      # Scrollback
      scrollback-limit = 10000;

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

      # Key bindings
      # Ghostty uses different keybind syntax than WezTerm
      # New tab: Ctrl+Shift+T (default)
      # Close tab: Ctrl+Shift+W (default)
      # Copy: Ctrl+Shift+C (default)
      # Paste: Ctrl+Shift+V (default)
    };
  };

}
