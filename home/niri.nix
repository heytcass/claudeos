{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  themeLib = import ../lib/theme.nix;
  # Stylix base16 palette — used to derive Noctalia Material Design color tokens
  c = config.lib.stylix.colors.withHashtag;
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
    fuzzel.enable = true; # Derives colors + font from Stylix base16 scheme
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

  # Fuzzel launcher — colors and font are injected by Stylix
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        prompt = "\"❯  \"";
        layer = "overlay";
        lines = 8;
        width = 35;
        horizontal-pad = 16;
        vertical-pad = 10;
        inner-pad = 8;
      };
      border = {
        width = 2;
        radius = 12;
      };
    };
  };

  # Niri compositor configuration
  programs.niri.settings = {
    # Output arrangement — dock: dual Dell P2419H + laptop
    # Connector names are dock-port-specific, not monitor-specific
    outputs = {
      "DP-4" = {
        position = {
          x = 3840;
          y = 1026;
        };
        scale = 1.0;
        transform.rotation = 270;
      };
      "DP-3" = {
        position = {
          x = 0;
          y = 1359;
        };
        scale = 1.0;
      };
      "eDP-1" = {
        position = {
          x = 1920;
          y = 1866;
        };
        scale = 1.0;
      };
    };

    # Input — Colemak layout (must set explicitly since we don't use services.xserver)
    input = {
      keyboard.xkb = {
        layout = "us";
        variant = "colemak";
      };
      touchpad = {
        click-method = "clickfinger";
        tap = false;
      };
    };

    # Layout
    layout = {
      gaps = 8;
      border.width = 1; # 1px like claude.ai — colors from Stylix via niri.homeModules.stylix
      preset-column-widths = [
        { proportion = 1.0 / 3; }
        { proportion = 1.0 / 2; }
        { proportion = 2.0 / 3; }
      ];
      default-column-width = {
        proportion = 1.0 / 2;
      };
      center-focused-column = "on-overflow";
      # Transparent so Noctalia's layer-shell wallpaper surface shows through
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
    # NOTE: Noctalia Shell is managed by systemd (programs.noctalia-shell.systemd.enable)
    # — do NOT also spawn it here or you get duplicate bars
    spawn-at-startup = [
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

        # Claude integration
        "Mod+A".action = spawn "claude-ask-desktop"; # Desktop search
        "Mod+Shift+A".action = spawn "claude-screenshot"; # Screenshot analysis (notification)
        "Mod+Ctrl+A".action = spawn "claude-screenshot-interactive"; # Screenshot analysis (terminal)

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
  programs.noctalia-shell = {
    enable = true;
    systemd.enable = true; # Auto-restarts on failure, reloads on config change

    # Stylix-derived Material Design color tokens — keeps bar in sync with the rest of the desktop
    colors = {
      mPrimary = c.base0D; # Terracotta — primary accent
      mSecondary = c.base0E; # Warm brown — secondary accent
      mTertiary = c.base0C; # Blue — tertiary accent (info, links)
      mError = c.base08; # Dark terracotta — errors, destructive
      mSurface = c.base00; # Dark background
      mSurfaceVariant = c.base01; # Elevated surface (cards, popovers)
      mOnPrimary = c.base00; # Text on primary accent
      mOnSecondary = c.base00; # Text on secondary accent
      mOnTertiary = c.base00; # Text on tertiary accent
      mOnSurface = c.base05; # Primary foreground text
      mOnSurfaceVariant = c.base04; # Secondary foreground text
      mOnError = c.base00; # Text on error
      mOutline = c.base03; # Borders, dividers, dim text
      mShadow = c.base00; # Drop shadows
      mHover = c.base0C; # Blue — hover highlight
      mOnHover = c.base00; # Text on hover
    };

    # Declarative settings — mkForce overrides Noctalia module defaults
    settings = lib.mkForce {
      # Bar — floating compact style
      bar = {
        barType = "floating";
        floating = true;
        position = "top";
        density = "compact";
        backgroundOpacity = 0.8;
        capsuleOpacity = 0.8;
        showCapsule = true;
        showOutline = true;
        frameRadius = 12;
        outerCorners = true;
        marginVertical = 6;
        marginHorizontal = 8;
        hideOnOverview = true;
        displayMode = "always_visible";
        widgets = {
          left = [
            {
              id = "Launcher";
              icon = "rocket";
            }
            {
              id = "Workspace";
              hideUnoccupied = true;
              focusedColor = "primary";
              pillSize = 0.6;
              showBadge = true;
            }
            {
              id = "ActiveWindow";
              showIcon = true;
              colorizeIcons = true;
              maxWidth = 200;
              scrollingMode = "hover";
              hideMode = "transparent";
            }
          ];
          center = [
            { id = "plugin:jasper-insights"; }
            {
              id = "Clock";
              formatHorizontal = "h:mm AP  |  ddd, MMM dd";
              clockColor = "none";
            }
            {
              id = "MediaMini";
              hideMode = "hidden";
              maxWidth = 145;
              scrollingMode = "hover";
              showAlbumArt = true;
              showProgressRing = true;
              showArtistFirst = true;
            }
          ];
          right = [
            { id = "Tray"; }
            {
              id = "Network";
              displayMode = "onhover";
            }
            {
              id = "Volume";
              displayMode = "onhover";
            }
            {
              id = "Battery";
              displayMode = "graphic-clean";
              hideIfIdle = false;
            }
            {
              id = "Brightness";
              displayMode = "onhover";
            }
            {
              id = "NotificationHistory";
              showUnreadBadge = true;
              unreadBadgeColor = "primary";
            }
            { id = "ControlCenter"; }
          ];
        };
      };

      # Dock — disabled
      dock = {
        enabled = false;
        position = "bottom";
        displayMode = "auto_hide";
        backgroundOpacity = 0.7;
        size = 1;
        onlySameOutput = true;
        pinnedApps = [
          "google-chrome"
          "code"
          "ghostty"
        ];
      };

      # Notifications — top-right, overlay
      notifications = {
        enabled = true;
        density = "compact";
        location = "top_right";
        overlayLayer = true;
        backgroundOpacity = 0.75;
        normalUrgencyDuration = 6;
        criticalUrgencyDuration = 12;
      };

      # OSD — volume/brightness popups
      osd = {
        enabled = true;
        location = "top_right";
        autoHideMs = 1500;
        backgroundOpacity = 0.75;
      };

      # Wallpaper — Noctalia renders the Stylix image via layer-shell backdrop
      wallpaper = {
        enabled = true;
        viewMode = "single";
        fillMode = "crop";
      };

      # Color scheme — use our Nix-declared colors, not wallpaper-derived
      colorSchemes = {
        useWallpaperColors = false;
        darkMode = true;
      };

      # Templates — disabled so Noctalia doesn't overwrite Stylix's GTK CSS / Ghostty theme
      templates = {
        activeTemplates = [ ];
        enableUserTheming = false;
      };

      # App launcher
      appLauncher = {
        position = "center";
        viewMode = "list";
        terminalCommand = "ghostty -e";
        sortByMostUsed = true;
        pinnedApps = [ "com.mitchellh.ghostty" ];
      };

      # UI — fonts, panels attached to bar
      ui = {
        fontDefault = themeLib.fonts.sansSerif.name;
        fontFixed = "JetBrainsMono Nerd Font Mono";
        panelBackgroundOpacity = 0.7;
        panelsAttachedToBar = true;
        tooltipsEnabled = true;
      };

      # General shell behavior
      general = {
        avatarImage = builtins.toString ../assets/avatar.jpg;
        lockOnSuspend = true;
        enableShadows = true;
        animationSpeed = 1.0;
        scaleRatio = 0.8;
        reverseScroll = true;
        telemetryEnabled = false;
      };

      # Location & weather
      location = {
        name = "Rochester Hills, MI";
        useFahrenheit = true;
        use12hourFormat = true;
        weatherEnabled = true;
        hideWeatherTimezone = true;
      };

      # Night light — auto-schedule based on location sunrise/sunset
      nightLight = {
        enabled = true;
        autoSchedule = true;
        nightTemp = "4000";
      };

      # Control center cards
      controlCenter = {
        cards = [
          {
            id = "profile-card";
            enabled = true;
          }
          {
            id = "shortcuts-card";
            enabled = true;
          }
          {
            id = "audio-card";
            enabled = true;
          }
          {
            id = "brightness-card";
            enabled = false;
          }
          {
            id = "weather-card";
            enabled = true;
          }
          {
            id = "media-sysmon-card";
            enabled = true;
          }
        ];
      };

      # Calendar panel cards
      calendar = {
        cards = [
          {
            id = "calendar-header-card";
            enabled = true;
          }
          {
            id = "calendar-month-card";
            enabled = true;
          }
          {
            id = "weather-card";
            enabled = true;
          }
        ];
      };

      # Audio
      audio = {
        volumeStep = 5;
        volumeOverdrive = false;
        volumeFeedback = false;
      };
    };
  };
}
