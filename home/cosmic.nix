{ pkgs, ... }:

{
  # GTK theme preferences
  # These apply to GTK applications running under COSMIC
  gtk = {
    enable = true;

    # Icon theme — Adwaita provides symbolic icons for GTK/libadwaita apps
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };

    # Force dark mode preference for GTK3/4 applications
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
  };

  # dconf settings for GTK app compatibility
  # COSMIC uses its own config system in ~/.config/cosmic
  # but respects dconf for GTK applications
  dconf.settings = {
    # Desktop interface preferences (for GTK apps)
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      icon-theme = "Adwaita";
    };
  };

  # COSMIC configuration
  # Most COSMIC settings are managed through the Settings app GUI
  # Advanced configuration can be done via ~/.config/cosmic/ files
}
