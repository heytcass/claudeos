{ lib, pkgs, ... }:

{
  # Stylix theming with Claude brand colors
  # Replaces the previous Adwaita-based theme with a custom base16 scheme
  # that matches Claude's warm, minimal aesthetic
  stylix = {
    enable = true;

    # Claude-inspired base16 color scheme
    # Warm, muted palette with terracotta accents
    base16Scheme = {
      base00 = "262624"; # Default background — the dominant warm dark grey
      base01 = "30302e"; # Elevated surface (cards, input box, popovers)
      base02 = "3a3a38"; # Selection / highlighted regions (slightly lighter step)
      base03 = "9c9a92"; # Comments / dim text / placeholders
      base04 = "c2c0b6"; # Secondary foreground text
      base05 = "faf9f5"; # Primary foreground text
      base06 = "faf9f5"; # Light foreground (same warm off-white)
      base07 = "ffffff"; # Brightest white (rare, high-contrast)

      base08 = "c6613f"; # Red — terracotta accent
      base09 = "d97757"; # Orange — lighter terracotta
      base0A = "c9b87c"; # Yellow — warm sand (invented, keeps warm tone)
      base0B = "8a9a6b"; # Green — muted olive (invented)
      base0C = "6b9e8a"; # Cyan — warm sage (invented)
      base0D = "2c84db"; # Blue — link/info blue
      base0E = "a67a5b"; # Magenta — warm brown (invented, fits palette)
      base0F = "d97757"; # Brown — lighter terracotta
    };

    # Claude wallpaper — centered asterisk on dark background
    image = ../../assets/claude.png;
    imageScalingMode = "fill";

    # Dark mode theme
    polarity = "dark";

    # Icon theme configuration
    # Note: Stylix automatic icon theming disabled due to compatibility issues
    # Icon theme is configured directly in modules/desktop/cosmic.nix via GTK
    icons = {
      enable = false;
      package = pkgs.adwaita-icon-theme;
    };

    # Font configuration - use Inter font from fonts.nix
    # Must be explicitly set for Stylix to work properly
    fonts = {
      serif = {
        package = pkgs.noto-fonts;
        name = "Noto Serif";
      };
      sansSerif = {
        package = pkgs.inter;
        name = "Inter";
      };
      monospace = {
        package = pkgs.jetbrains-mono;
        name = "JetBrains Mono";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
    };
  };

  # Qt applications should use GTK theme for consistency
  qt = {
    enable = true;
    platformTheme = lib.mkForce "gtk2"; # COSMIC uses GTK platform theme
    style = lib.mkForce "adwaita-dark";
  };

  # XDG portal for better desktop integration
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-cosmic
      xdg-desktop-portal-gtk
    ];
    config.common.default = "cosmic";
  };
}
