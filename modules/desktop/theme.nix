{ lib, pkgs, ... }:

let
  themeLib = import ../../lib/theme.nix;
in
{
  # Stylix theming with Claude brand colors
  stylix = {
    enable = true;

    # Claude-inspired base16 color scheme
    # Warm, muted palette with terracotta accents
    base16Scheme = {
      base00 = "1f1e1d"; # Default background — Claude's deepest surface
      base01 = "262624"; # Elevated surface (cards, input box, popovers)
      base02 = "30302e"; # Selection / highlighted regions (slightly lighter step)
      base03 = "9c9a92"; # Comments / dim text / placeholders
      base04 = "c2c0b6"; # Secondary foreground text
      base05 = "faf9f5"; # Primary foreground text
      base06 = "faf9f5"; # Light foreground (same warm off-white)
      base07 = "ffffff"; # Brightest white (rare, high-contrast)

      base08 = "c6613f"; # Red — terracotta accent
      base09 = "d97757"; # Orange — lighter terracotta
      base0A = "c9b87c"; # Yellow — warm sand
      base0B = "8a9a6b"; # Green — muted olive
      base0C = "6b9e8a"; # Cyan — warm sage
      base0D = "2c84db"; # Blue — link/info blue
      base0E = "a67a5b"; # Magenta — warm brown
      base0F = "d97757"; # Brown — lighter terracotta
    };

    # Claude wallpaper — centered asterisk on dark background
    image = ../../assets/claude.png;
    imageScalingMode = "fill";

    # Dark mode theme
    polarity = "dark";

    # Font configuration — names from lib/theme.nix, packages declared here
    fonts = {
      serif = {
        package = pkgs.noto-fonts;
        name = themeLib.fonts.serif.name;
      };
      sansSerif = {
        package = pkgs.inter;
        name = themeLib.fonts.sansSerif.name;
      };
      monospace = {
        package = pkgs.jetbrains-mono;
        name = themeLib.fonts.monospace.name;
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = themeLib.fonts.emoji.name;
      };
    };
  };

  # Qt applications should use GTK theme for consistency
  qt = {
    enable = true;
    platformTheme = lib.mkForce "gtk2";
    style = lib.mkForce "adwaita-dark";
  };

  # XDG portal for better desktop integration
  # niri-flake auto-adds xdg-desktop-portal-gnome; we keep GTK as fallback
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
    config.common.default = "gtk";
  };
}
