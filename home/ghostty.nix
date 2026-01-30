{ lib, ... }:

{
  programs.ghostty = {
    enable = true;

    # Ghostty configuration
    # Colors are managed by Stylix - see modules/desktop/theme.nix
    settings = {
      # Font configuration - JetBrains Mono for readability
      font-family = "JetBrains Mono Nerd Font";
      font-size = 11;

      # Cursor
      cursor-style = "block";
      cursor-style-blink = false;

      # Window configuration
      window-padding-x = 8;
      window-padding-y = 8;
      window-decoration = true; # Use native GTK decorations

      # GTK/libadwaita integration for native GNOME look
      gtk-titlebar = true;
      gtk-tabs-location = "hidden"; # No tab bar for clean look

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

  # Shell integration for Fish
  # Ghostty provides automatic integration when shell-integration is enabled
  programs.fish.shellInit = lib.mkAfter ''
    # Ghostty shell integration is automatically loaded
  '';
}
