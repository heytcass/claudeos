{ config, lib, pkgs, ... }:

{
  # Using GNOME's default Adwaita theme for now
  # This provides a clean, minimal, professional aesthetic that matches Claude's design philosophy
  #
  # Future enhancement: Consider Stylix with Claude brand colors:
  #   - Dark: #141413, Light: #faf9f5, Orange: #d97757
  #   - Blue: #6a9bcc, Green: #788c5d
  #
  # Alternative themes that match Claude's aesthetic:
  #   - Prof-Gnome-theme: Professional, minimalistic, neutral tones
  #   - HyperFluent: Modern, clean, frosted glass effects
  #   - MoreWaita icons: Adwaita-style with orange accents (matches Claude brand)
  #   - Bibata cursor: Modern, minimal, material design

  # GTK theme configuration
  # Adwaita is GNOME's default - clean, minimal, universally recognizable
  environment.systemPackages = with pkgs; [
    # Additional theme tools
    adwaita-icon-theme  # Explicit inclusion for consistency
  ];

  # Enable GTK themes
  programs.dconf.enable = true;

  # Qt applications should use GTK theme for consistency
  qt = {
    enable = true;
    platformTheme = "gnome";
    style = "adwaita";
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
