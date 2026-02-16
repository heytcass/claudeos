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

  # COSMIC custom keyboard shortcuts for Claude
  home.file.".config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom".text = ''
    {
        (modifiers: [Super], key: "c"): Spawn("claude-quick"),
        (modifiers: [Ctrl, Alt], key: "space"): Spawn("claude-desktop"),
    }
  '';

  # COSMIC Panel layout
  # Center: Jasper AI status + clock + weather (ambient glance targets)
  # Left wing: workspace switcher
  # Right wing: decluttered — StatusArea covers audio/bluetooth/network/battery
  home.file.".config/cosmic/com.system76.CosmicPanel.Panel/v1/plugins_center".text = ''
    Some([
        "com.system76.CosmicAppletJasper",
        "com.system76.CosmicAppletTime",
        "io.github.cosmic_utils.weather-applet",
    ])
  '';
  home.file.".config/cosmic/com.system76.CosmicPanel.Panel/v1/plugins_wings".text = ''
    Some(([
        "com.system76.CosmicPanelWorkspacesButton",
    ], [
        "net.tropicbliss.CosmicExtAppletCaffeine",
        "com.system76.CosmicAppletStatusArea",
        "com.system76.CosmicAppletTiling",
        "com.system76.CosmicAppletAudio",
        "com.system76.CosmicAppletBluetooth",
        "com.system76.CosmicAppletNetwork",
        "com.system76.CosmicAppletBattery",
        "com.system76.CosmicAppletNotifications",
        "com.system76.CosmicAppletPower",
    ]))
  '';

  # COSMIC Dock — medium icons, snappy auto-hide
  home.file.".config/cosmic/com.system76.CosmicPanel.Dock/v1/size".text = "M";
  home.file.".config/cosmic/com.system76.CosmicPanel.Dock/v1/autohide".text = ''
    Some((
        wait_time: 500,
        transition_time: 200,
        handle_size: 4,
        unhide_delay: 100,
    ))
  '';

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
