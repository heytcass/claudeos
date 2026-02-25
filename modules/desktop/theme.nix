{ lib, pkgs, ... }:

let
  themeLib = import ../../lib/theme.nix;
in
{
  # Stylix theming with Claude brand colors
  stylix = {
    enable = true;

    # Claude.ai base16 color scheme — values extracted from live claude.ai CSS tokens
    # Backgrounds (base00–02) = --bg-200/100/000, Text (03–07) = --text-400/200/100
    # Accent hierarchy: terracotta (--accent-brand) is primary, blue (--accent-secondary) is secondary
    base16Scheme = {
      base00 = "1f1e1d"; # --bg-200  — deepest background
      base01 = "262624"; # --bg-100  — main body background
      base02 = "30302e"; # --bg-000  — elevated surface (input box, cards)
      base03 = "9c9a92"; # --text-400 — muted text / placeholders
      base04 = "c2c0b6"; # --text-200 — secondary text
      base05 = "faf9f5"; # --text-100 — primary text
      base06 = "faf9f5"; # --text-000 — bright text
      base07 = "ffffff"; # --oncolor-100 — pure white

      base08 = "c6613f"; # --accent-main-000 — dark terracotta (errors, destructive)
      base09 = "e6956b"; # Warm peach — lighter accent for constants/highlights
      base0A = "c9b87c"; # Warm sand — warnings, classes
      base0B = "8a9a6b"; # Muted olive — success, strings
      base0C = "2c84db"; # --accent-secondary-100 — blue (info, links, secondary accent)
      base0D = "d97757"; # --accent-brand — TERRACOTTA (primary accent, functions, borders)
      base0E = "a67a5b"; # Warm brown — keywords, special
      base0F = "bd5d3a"; # Deep terracotta — hover state, embedded
    };

    # Topographic contour wallpaper — terracotta lines on dark charcoal
    image = ../../assets/topo-wallpaper.png;
    imageScalingMode = "fill";

    # Dark mode theme
    polarity = "dark";

    # Cursor theme — must set all three for Stylix to manage home.pointerCursor
    cursor = {
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
      size = 20;
    };

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
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = themeLib.fonts.monospace.nerdName;
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
