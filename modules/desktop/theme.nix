{ pkgs, ... }:

{
  # Stylix theming with Claude brand colors
  # Replaces the previous Adwaita-based theme with a custom base16 scheme
  # that matches Claude's warm, minimal aesthetic
  stylix = {
    enable = true;

    # Claude-inspired base16 color scheme
    # Warm, muted palette with terracotta accents
    base16Scheme = {
      # Base colors (backgrounds and foregrounds)
      base00 = "14140f"; # Default background (darkest — headerbar/deep surface)
      base01 = "262624"; # Lighter background (main body/sidebar)
      base02 = "30302e"; # Selection/surface (input box, cards)
      base03 = "9c9a92"; # Comments / dim text
      base04 = "c2c0b6"; # Dark foreground (secondary text)
      base05 = "faf9f5"; # Default foreground (primary text)
      base06 = "faf9f5"; # Light foreground (same — Claude doesn't really have a brighter white)
      base07 = "ffffff"; # Lightest (pure white, for rare high-contrast)

      # Accent colors
      base08 = "c6613f"; # Red — terracotta accent (also destructive)
      base09 = "d97757"; # Orange — lighter terracotta
      base0A = "c2c0b6"; # Yellow — warm muted (Claude doesn't have a true yellow)
      base0B = "9c9a92"; # Green — repurpose as muted olive
      base0C = "6b9e8a"; # Cyan — warm sage green to fit the palette
      base0D = "2c84db"; # Blue — the link/info blue
      base0E = "c6613f"; # Magenta — map back to terracotta to keep the warm feel
      base0F = "d97757"; # Brown — lighter terracotta
    };

    # No wallpaper - keep clean desktop
    image = null;

    # Dark mode theme
    polarity = "dark";

    # Keep existing font configuration (Inter) from fonts.nix
    # Stylix can override fonts, but we explicitly don't set them here
    # to preserve the Inter font family configured elsewhere
  };

  # Qt applications should use GTK theme for consistency
  qt = {
    enable = true;
    platformTheme = "gnome";
    style = "adwaita-dark";
  };

  # XDG portal for better desktop integration
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
    ];
    config.common.default = "gnome";
  };
}
