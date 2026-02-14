{ pkgs, ... }:

let
  themeLib = import ../lib/theme.nix;
in
{
  # Stylix target configuration — controls which apps get themed
  stylix.targets = {
    gtk.enable = true;
    ghostty.enable = true;
    vscode.enable = true;
    fzf.enable = true;
    bat.enable = true;
    lazygit.enable = true;
  };

  # GTK theme preferences
  # These apply to GTK applications running under COSMIC
  gtk = {
    enable = true;

    # Icon theme — Adwaita provides symbolic icons for GTK/libadwaita apps
    iconTheme = {
      name = themeLib.icons.name;
      package = pkgs.adwaita-icon-theme;
    };

    # Force dark mode preference for GTK3/4 applications
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
  };

  # Force overwrite GTK CSS files that Stylix manages
  xdg.configFile = {
    "gtk-3.0/gtk.css".force = true;
    "gtk-4.0/gtk.css".force = true;
  };

  # dconf settings for GTK app compatibility
  # COSMIC uses its own config system in ~/.config/cosmic
  # but respects dconf for GTK applications
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      icon-theme = themeLib.icons.name;
    };
  };
}
