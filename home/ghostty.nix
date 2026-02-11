{ lib, ... }:

{
  programs.ghostty = {
    enable = true;

    # Ghostty configuration
    settings = {
      # Font configuration - JetBrains Mono for readability
      font-family = "JetBrains Mono Nerd Font";
      font-size = 11;

      # Claude-inspired color scheme (no theme name, define colors directly)
      # Background and foreground
      background = "1a1d23";
      foreground = "e0e0e0";

      # Cursor
      cursor-color = "f5a97f";
      cursor-text = "1a1d23";
      cursor-style = "block";
      cursor-style-blink = false;

      # Selection
      selection-foreground = "1a1d23";
      selection-background = "4a5568";

      # ANSI colors - normal (0-7) and bright (8-15)
      # Format: "index=#hexcolor"
      palette = [
        "0=#1a1d23" # black
        "1=#e06c75" # red
        "2=#98c379" # green
        "3=#e5c07b" # yellow
        "4=#61afef" # blue
        "5=#c678dd" # magenta
        "6=#56b6c2" # cyan
        "7=#abb2bf" # white
        "8=#5c6370" # bright black
        "9=#e06c75" # bright red
        "10=#98c379" # bright green
        "11=#e5c07b" # bright yellow
        "12=#61afef" # bright blue
        "13=#c678dd" # bright magenta
        "14=#56b6c2" # bright cyan
        "15=#ffffff" # bright white
      ];

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
