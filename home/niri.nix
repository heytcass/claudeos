{
  config,
  pkgs,
  inputs,
  ...
}:

let
  themeLib = import ../lib/theme.nix;
in
{
  # niri-flake NixOS module auto-imports homeModules.niri + homeModules.stylix
  # when home-manager is detected — only import Noctalia here
  imports = [
    inputs.noctalia.homeModules.default
  ];

  # Stylix target configuration — controls which apps get themed
  stylix.targets = {
    gtk.enable = true;
    ghostty.enable = true;
    vscode.enable = true;
    fzf.enable = true;
    bat.enable = true;
    lazygit.enable = true;
    niri.enable = true; # niri-flake: auto-derives border colors + cursor from Stylix
  };

  # GTK theme preferences
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
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      icon-theme = themeLib.icons.name;
    };
  };

  # Niri compositor configuration
  programs.niri.settings = {
    # Input — Colemak layout (must set explicitly since we don't use services.xserver)
    input = {
      keyboard.xkb = {
        layout = "us";
        variant = "colemak";
      };
    };

    # Layout
    layout = {
      gaps = 8;
      border.width = 2; # Colors auto-derived from Stylix via niri.homeModules.stylix
      preset-column-widths = [
        { proportion = 1.0 / 3; }
        { proportion = 1.0 / 2; }
        { proportion = 2.0 / 3; }
      ];
      default-column-width = {
        proportion = 1.0 / 2;
      };
      center-focused-column = "on-overflow";
      # Transparent background so Noctalia wallpaper shows through
      background-color = "transparent";
    };

    # Window rules
    window-rules = [
      # Claude quick-launch: floating window
      {
        matches = [ { app-id = "^claude-quick$"; } ];
        open-floating = true;
      }
      # Rounded corners on all windows
      {
        geometry-corner-radius =
          let
            r = 12.0;
          in
          {
            top-left = r;
            top-right = r;
            bottom-left = r;
            bottom-right = r;
          };
        clip-to-geometry = true;
      }
    ];

    # Layer rules for Noctalia wallpaper backdrop
    layer-rules = [
      {
        matches = [ { namespace = "^noctalia-wallpaper"; } ];
        place-within-backdrop = true;
      }
      {
        matches = [ { namespace = "^noctalia-overview"; } ];
        place-within-backdrop = true;
      }
    ];

    # Debug flags (no-argument nodes must be empty lists)
    debug = {
      # Required for Noctalia notification activation
      honor-xdg-activation-with-invalid-serial = [ ];
    };

    # Processes to spawn at startup
    spawn-at-startup = [
      { command = [ "noctalia-shell" ]; }
      {
        command = [
          "${pkgs.wl-clipboard}/bin/wl-paste"
          "--watch"
          "${pkgs.cliphist}/bin/cliphist"
          "store"
        ];
      }
    ];

    # Keybindings
    binds =
      with config.lib.niri.actions;
      let
        sh = spawn "sh" "-c";
      in
      {
        # Application launchers
        "Mod+Return".action = spawn "ghostty";
        "Mod+C".action = spawn "claude-quick";
        "Ctrl+Alt+Space".action = spawn "claude-desktop";
        "Mod+D".action = spawn "fuzzel";

        # Window management
        "Mod+Q".action = close-window;
        "Mod+F".action = fullscreen-window;
        "Mod+Space".action = switch-preset-column-width;
        "Mod+V".action = toggle-window-floating;
        "Mod+Comma".action = consume-window-into-column;
        "Mod+Period".action = expel-window-from-column;

        # Focus
        "Mod+Left".action = focus-column-left;
        "Mod+Right".action = focus-column-right;
        "Mod+Up".action = focus-workspace-up;
        "Mod+Down".action = focus-workspace-down;

        # Move windows
        "Mod+Shift+Left".action = move-column-left;
        "Mod+Shift+Right".action = move-column-right;
        "Mod+Shift+Up".action = move-window-up-or-to-workspace-up;
        "Mod+Shift+Down".action = move-window-down-or-to-workspace-down;

        # Workspace switching
        "Mod+1".action = focus-workspace 1;
        "Mod+2".action = focus-workspace 2;
        "Mod+3".action = focus-workspace 3;
        "Mod+4".action = focus-workspace 4;
        "Mod+5".action = focus-workspace 5;

        # Move to workspace (not in config.lib.niri.actions — use object syntax)
        "Mod+Shift+1".action.move-column-to-workspace = [ 1 ];
        "Mod+Shift+2".action.move-column-to-workspace = [ 2 ];
        "Mod+Shift+3".action.move-column-to-workspace = [ 3 ];
        "Mod+Shift+4".action.move-column-to-workspace = [ 4 ];
        "Mod+Shift+5".action.move-column-to-workspace = [ 5 ];

        # Overview
        "Mod+Tab".action = toggle-overview;

        # Screen lock
        "Mod+L".action = spawn "swaylock";

        # Screenshot (not in config.lib.niri.actions — use object syntax)
        "Print".action.screenshot = [ ];
        "Ctrl+Print".action.screenshot-screen = [ ];
        "Alt+Print".action.screenshot-window = [ ];

        # Clipboard history
        "Mod+Shift+C".action =
          sh "${pkgs.cliphist}/bin/cliphist list | ${pkgs.fuzzel}/bin/fuzzel --dmenu | ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy";

        # Media keys
        "XF86AudioRaiseVolume".action = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+";
        "XF86AudioLowerVolume".action = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-";
        "XF86AudioMute".action = spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle";
        "XF86AudioMicMute".action = spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle";
        "XF86MonBrightnessUp".action = spawn "brightnessctl" "set" "5%+";
        "XF86MonBrightnessDown".action = spawn "brightnessctl" "set" "5%-";
      };
  };

  # Noctalia Shell — bar, notifications, OSD, wallpaper, lock screen, launcher
  # Start with defaults; refine via Noctalia's built-in settings UI, then declare in Nix
  programs.noctalia-shell = {
    enable = true;
    systemd.enable = true;
  };
}
