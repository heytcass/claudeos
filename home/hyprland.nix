# home/hyprland.nix — Hyprland + a bespoke Quickshell bar, per-user config.
# Attached by modules/desktop/hyprland.nix (claude-os.hyprland.enable), the
# default desktop since the Phase 1 inversion; absent wherever GNOME is the
# desktop (gti until reinstall, transporter's `gnome` fallback entry). All
# colors come from the Stylix base16 palette (never hardcoded hex) — CLAUDE.md
# mandate.
#
# The bar is hand-authored QML under ./quickshell (the "build what I want, adopt
# no one's desktop" choice); it is themed by a Colors.qml singleton generated
# from the Stylix palette below. Companions (launcher/notifications/lock/idle/
# wallpaper) are small tools that Stylix auto-themes.
{
  lib,
  pkgs,
  config,
  osConfig,
  ...
}:
let
  # Plain (no-hash) base16 strings for Hyprland's rgba() color syntax.
  c = config.lib.stylix.colors;

  # gsd's sleep-inactive-battery policy, reimplemented for hypridle: suspend
  # only when NO AC adapter reports online (sysfs `online` exists only on AC
  # supplies, so a battery-only match set means suspend). On AC the machine
  # stays awake — overnight automation (auto-update, diary, morning desk)
  # depends on it, same intent as home/gnome.nix's dconf power settings.
  suspendOnBattery = pkgs.writeShellScript "suspend-on-battery" ''
    for ac in /sys/class/power_supply/*/online; do
      [ -e "$ac" ] || continue
      [ "$(cat "$ac")" = "1" ] && exit 0
    done
    systemctl suspend
  '';

  # Font names for the Quickshell Theme singleton — same source of truth the
  # rest of the system themes from (lib/theme.nix), so the bar matches.
  themeLib = import ../lib/theme.nix;

  # Reuse THE keybinding source of truth — lib/keybindings.nix drives the GNOME
  # dconf binds AND the claudeos help screen, so converting it here keeps
  # Hyprland in sync by construction rather than duplicating the list.
  # Each entry's `binding` is a GTK accelerator like "<Super><Shift>a"; convert
  # to Hyprland's "SUPER SHIFT, A, exec, <command>".
  claudeBinds = import ../lib/keybindings.nix;
  modMap = {
    "Super" = "SUPER";
    "Shift" = "SHIFT";
    "Ctrl" = "CTRL";
    "Control" = "CTRL";
    "Alt" = "ALT";
  };
  bindTokens =
    b: lib.filter (s: s != "") (lib.splitString ">" (lib.replaceStrings [ "<" ] [ "" ] b.binding));
  toHyprBind =
    b:
    let
      tokens = bindTokens b;
      mods = lib.init tokens; # everything but the last token is a modifier
      key = lib.toUpper (lib.last tokens);
      hyprMods = lib.concatStringsSep " " (map (m: modMap.${m} or (lib.toUpper m)) mods);
      # An entry is either an exec bind (command) or a quickshell global.
      action = if b ? global then "global, ${b.global}" else "exec, ${b.command}";
    in
    "${hyprMods}, ${key}, ${action}";

  # The cheat sheet's Claude section, as data — CheatSheet.qml reads this from
  # the generated Keybinds.qml singleton, so Super+H can never drift from the
  # real binds again. JSON is a valid QML literal; toJSON does the escaping.
  cheatEntries = builtins.toJSON (
    map (b: {
      keys = lib.init (bindTokens b) ++ [ (lib.toUpper (lib.last (bindTokens b))) ];
      desc = b.short or b.help;
    }) claudeBinds
  );

  # One shared 4px rhythm: Hyprland's outer window gaps (general.gaps_out) and
  # the bar islands' screen-edge margins + float gap (Theme.edgeGap) all read
  # this, so the pills stay aligned with tiled window edges by construction.
  # Tightened 2026-07-12 for the 12.5" 1080p@1.5× panel.
  edgeGap = 4;

  # Assemble the Quickshell config dir: the static QML from ./quickshell plus a
  # Colors.qml singleton generated from the live Stylix palette. A directory
  # `.source` symlink can't have a file added inside it, so build the dir in a
  # derivation instead.
  qsConfig = pkgs.runCommand "claudeos-quickshell" { } ''
    mkdir -p "$out"
    cp -r ${./quickshell}/. "$out/"
    cat > "$out/Theme.qml" <<'EOF'
    pragma Singleton
    import Quickshell
    import QtQuick

    // Generated from the Stylix base16 palette + lib/theme.nix fonts. The whole
    // bar reads colors/fonts/metrics from here — never hardcode hex in the QML.
    Singleton {
      readonly property color base00: "#${c.base00}"
      readonly property color base01: "#${c.base01}"
      readonly property color base02: "#${c.base02}"
      readonly property color base03: "#${c.base03}"
      readonly property color base04: "#${c.base04}"
      readonly property color base05: "#${c.base05}"
      readonly property color base06: "#${c.base06}"
      readonly property color base07: "#${c.base07}"
      readonly property color base08: "#${c.base08}"
      readonly property color base09: "#${c.base09}"
      readonly property color base0A: "#${c.base0A}"
      readonly property color base0B: "#${c.base0B}"
      readonly property color base0C: "#${c.base0C}"
      readonly property color base0D: "#${c.base0D}"
      readonly property color base0E: "#${c.base0E}"
      readonly property color base0F: "#${c.base0F}"

      // Semantic aliases (so widgets read intent, not palette indices)
      readonly property color bg: base01
      readonly property color bgAlt: base00
      readonly property color surface: base02
      readonly property color text: base05
      readonly property color subtext: base04
      readonly property color muted: base03
      readonly property color accent: base0D
      readonly property color accentAlt: base0F
      readonly property color good: base0B
      readonly property color warn: base0A
      readonly property color urgent: base08

      // Fonts (single source of truth: lib/theme.nix)
      readonly property string fontSans: "${themeLib.fonts.sansSerif.name}"
      readonly property string fontMono: "${themeLib.fonts.monospace.nerdName}"
      readonly property int fontSize: 13
      readonly property int iconSize: 15

      // Metrics
      readonly property int barHeight: 34
      readonly property int radius: 8
      readonly property int gap: 8
      // Screen-edge inset + float gap for the islands — the same value as
      // Hyprland's gaps_out, interpolated from one Nix binding.
      readonly property int edgeGap: ${toString edgeGap}
    }
    EOF

    # Keybinds.qml — the Claude keybindings as data, generated from
    # lib/keybindings.nix (same source that drives the Hyprland binds and the
    # claudeos help screen). CheatSheet.qml reads Keybinds.claude, so the
    # Super+H cheat sheet stays in sync by construction. Edit the .nix, never
    # this file.
    cat > "$out/Keybinds.qml" <<'EOF'
    pragma Singleton
    import Quickshell
    import QtQuick

    Singleton {
      readonly property var claude: ${cheatEntries}
    }
    EOF

    # cava config for the island's audio spectrum (Spectrum.qml runs
    # `cava -p cava.conf`). Raw ascii on stdout: `bars` values 0..1000 per line,
    # ';'-separated, one frame per newline. bars here MUST match Spectrum.bars.
    cat > "$out/cava.conf" <<'EOF'
    [general]
    mode = normal
    bars = 14
    framerate = 60
    autosens = 1

    [input]
    method = pipewire
    source = auto

    [output]
    method = raw
    channels = mono
    mono_option = average
    raw_target = /dev/stdout
    data_format = ascii
    ascii_max_range = 1000
    bar_delimiter = 59
    frame_delimiter = 10
    EOF
  '';
in
{
  # Portals: the HM hyprland module auto-enables xdg.portal with ONLY the
  # hyprland backend, and HM's NIX_XDG_DESKTOP_PORTAL_DIR (hm-session-vars)
  # SHADOWS the system portal dir — so the frontend saw no gtk backend, and
  # FileChooser/Settings had no implementation (Claude Desktop SIGABRTed opening
  # a directory picker, 2026-07-11). Complete the per-user set instead: gtk
  # rides alongside xdph, and the config routes anything hyprland doesn't
  # implement (FileChooser, Settings, …) to gtk — mirroring the system module.
  xdg.portal = {
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = [
      "hyprland"
      "gtk"
    ];
  };

  # The bar owns network and bluetooth status (NetworkWidget/BluetoothWidget),
  # so the stock tray applets would double them up. Their packages stay —
  # nm-connection-editor and blueman-manager are the settings surfaces — but
  # the XDG autostart entries are shadowed Hidden: the user dir wins over
  # /run/current-system/sw/etc/xdg/autostart for the same basename, and the
  # systemd xdg-autostart generator skips Hidden entries.
  xdg.configFile."autostart/nm-applet.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=NetworkManager Applet
    Hidden=true
  '';
  xdg.configFile."autostart/blueman.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Blueman Applet
    Hidden=true
  '';

  wayland.windowManager.hyprland = {
    enable = true;
    # Pin the legacy hyprlang config format (this module's `settings` are
    # hyprlang, not lua) — silences the configType default-change warning.
    configType = "hyprlang";
    # UWSM owns the session (system module sets programs.hyprland.withUWSM);
    # don't also let home-manager start a hyprland systemd target.
    systemd.enable = false;

    settings = {
      "$mod" = "SUPER";
      "$terminal" = "ghostty";
      "$launcher" = "fuzzel";

      # Display scale + dock layout. Left unset, Hyprland auto-picks a
      # fractional scale from DPI (1.5 on these 1920x1080 panels); both hosts
      # want native 1:1 (100%) on the built-in panel instead.
      #
      # gti's desk dock (dialed in live 2026-07-17, all values validated via
      # `hyprctl keyword`): Dell | laptop | Dell-portrait, externals at 0.8 to
      # shrink their UI toward the 13" panel's density. The Dells are keyed by
      # desc/serial — DP-* port numbers shuffle between dock plug-ins, serials
      # don't. Physical alignment: left Dell's bottom lands at the laptop's
      # vertical midpoint; the portrait Dell is raised 201px so top-of-laptop
      # cursor crossings land level (density mismatch: the same logical span
      # covers ~9.4" of the portrait Dell vs 6.5" of laptop edge, so only one
      # crossing height can be physically true — we picked where Tom crosses).
      # Undocked, eDP-1's fixed offset is harmless (sole monitor, origin moot).
      monitor =
        if osConfig.networking.hostName == "gti" then
          [
            "eDP-1, 1920x1080@60, 2400x1320, 1"
            "desc:Dell Inc. DELL P2419H FXP0RB3, 1920x1080@60, 0x510, 0.8"
            "desc:Dell Inc. DELL P2419H 9HYLVF3, 1920x1080@60, 4320x-201, 0.8, transform, 3"
            # Anything else (projectors, other docks): sane default, no 1.5 auto.
            ", preferred, auto, 1"
          ]
        else
          [
            "eDP-1, preferred, auto, 1"
          ];

      # Keyboard: Hyprland owns the in-session Wayland layout (it does NOT
      # inherit GNOME's dconf input-sources), so mirror the Colemak setup from
      # home/gnome.nix here. The console keymap lives in modules/common/locale.nix.
      input = {
        kb_layout = "us";
        kb_variant = "colemak";
        # gsd parity (home/gnome.nix dconf): 250ms delay, 25ms interval —
        # Hyprland expresses the interval as a rate, 1000/25 = 40 repeats/s.
        repeat_delay = 250;
        repeat_rate = 40;
        # GNOME had tap-to-click flipped on for the same laptops; Hyprland's
        # default agrees, but the papercut is bad enough to pin explicitly.
        touchpad."tap-to-click" = true;
      };

      # Cursor: point Xcursor at the Stylix Adwaita theme (cursor.package +
      # size from modules/desktop/theme.nix) so the built-in Hyprland cursor
      # doesn't show. Also applied live via `hyprctl setcursor` in exec-once.
      env = [
        "XCURSOR_THEME,Adwaita"
        "XCURSOR_SIZE,20"
      ];

      # NB: hyprpaper, hypridle, and gammastep are deliberately NOT here —
      # they run as home-manager systemd units bound to graphical-session
      # .target, which UWSM activates. That makes the session-entry choice at
      # regreet LOAD-BEARING: the plain "Hyprland" entry never activates the
      # target, stranding all three (no wallpaper, no idle-lock, no night
      # light — observed first post-inversion login 2026-07-12). Always pick
      # "Hyprland (UWSM)"; regreet remembers the last choice per user in
      # /var/lib/regreet/state.toml.
      exec-once = [
        "qs" # the bespoke Quickshell bar
        # Apply the Adwaita cursor at runtime (belt-and-suspenders with env above).
        "hyprctl setcursor Adwaita 20"
        # Start + unlock the Secret Service (org.freedesktop.secrets) so Claude
        # and other libsecret apps can save logins. GNOME (co-installed) provides
        # gnome-keyring and the GDM PAM unlock; a bare WM session must still start
        # the daemon's components itself.
        "gnome-keyring-daemon --start --components=secrets,ssh,pkcs11"
        # Polkit agent (soteria). Launched here, NOT via its systemd --user
        # service: that service starts at graphical-session.target but the user
        # manager's environment lacks XDG_SESSION_ID (UWSM exports it too late),
        # so soteria dies with "Could not get XDG session id" and start-limit-
        # hits. exec-once inherits the live session env, so it registers fine.
        # Its systemd unit's autostart is disabled in modules/desktop/hyprland.nix.
        "soteria"
      ];

      general = {
        border_size = 2;
        # Tightened 2026-07-12 (was 4/8): on the 12.5" 1080p@1.5× panel the
        # airy gaps read as dead space and windows felt cramped. Dialed in
        # live via `hyprctl keyword general:gaps_*`.
        gaps_in = 2;
        gaps_out = edgeGap; # shared with the bar's Theme.edgeGap (see above)
        # Border colors come from Stylix's Hyprland target (base0D terracotta on
        # the active border, from the same palette) — setting them here conflicts
        # with Stylix's own definitions.
      };

      decoration.rounding = 6; # matched to the tighter gaps (was 8)

      # dwindle (default layout): keep the split direction when a window closes
      # so the layout doesn't reflow unexpectedly.
      dwindle.preserve_split = true;

      # Auto-float utility windows + the GTK file picker, so dialogs don't tile
      # awkwardly. Match by app class; add more as they come up.
      # Hyprland 0.55 hyprlang-compat grammar (verified against
      # src/config/legacy/ConfigManager.cpp @ v0.55.4): comma-separated
      # `<effect> <value>` fields plus at least one `match:<prop> <regex>` —
      # e.g. `float on, match:class ^(foo)$`. The bare `float class:^(foo)$`
      # form parses as an effect with a garbage value and NO match prop, i.e.
      # a rule that matches nothing (it sat here silently inert until
      # 2026-07-11). Effect names per WindowRuleEffectContainer.cpp
      # (`dim_around`, not `dimaround`).
      windowrule = [
        "float on, match:class ^(pavucontrol|nm-connection-editor|blueman-manager|org.gnome.Calculator)$"
        "float on, match:class ^(xdg-desktop-portal-gtk)$"
        # Morning desk (Chrome --app on ~/Desk/today/index.html) presents like
        # the SUPER+H cheat sheet: floating card, everything behind it dimmed.
        # The class derives from the fixed file path; Super+Q dismisses (a real
        # window can't do the overlay's click-away). Size is a % of the monitor
        # so it fits every host (a fixed 900px ran off a 720px-logical laptop);
        # claudeos-desk-open (morning-desk.nix) reads the mapped size back and
        # nudges the window to true center post-map — the rule's own position
        # effects lose a race with Chrome's first configure, and `center` is
        # fooled by Chrome's CSD shadow geometry.
        "float on, size 85% 90%, dim_around on, match:class ^(chrome-.*Desk_today_index\\.html-Default)$"
      ];

      # Drag to move (SUPER+left), drag to resize (SUPER+right) — the biggest
      # everyday win a bare compositor otherwise lacks.
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      bind = [
        "$mod, Return, exec, $terminal"
        "$mod, Q, killactive,"
        "$mod, Space, exec, $launcher"
        "$mod, L, exec, hyprlock"
        "$mod, V, togglefloating,"
        "$mod, F, fullscreen,"
        "$mod, P, pseudo," # toggle pseudo-tiling for the focused window
        "$mod, H, global, quickshell:cheatsheet" # floating keybind cheat sheet
        "$mod, I, global, quickshell:caffeine" # idle-inhibit hold (Caffeine.qml)
        # Super+W (wish overlay) now rides lib/keybindings.nix as a `global`
        # entry, alongside the exec binds — one source of truth for all of them.

        # Focus with arrows — layout-independent (no vim h/j/k/l: the physical
        # keys don't land on the home row under Colemak, so they're not muscle
        # memory here).
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"

        # Move the focused window within the layout.
        "$mod SHIFT, left, movewindow, l"
        "$mod SHIFT, right, movewindow, r"
        "$mod SHIFT, up, movewindow, u"
        "$mod SHIFT, down, movewindow, d"

        # Resize the focused window (40px steps).
        "$mod CTRL, left, resizeactive, -40 0"
        "$mod CTRL, right, resizeactive, 40 0"
        "$mod CTRL, up, resizeactive, 0 -40"
        "$mod CTRL, down, resizeactive, 0 40"

        # Scratchpad: SUPER+S toggles a hidden "magic" workspace, SUPER+SHIFT+S
        # stashes the focused window into it.
        "$mod, S, togglespecialworkspace, magic"
        "$mod SHIFT, S, movetoworkspace, special:magic"

        "$mod SHIFT, M, exit," # graceful exit back to GDM
      ]
      ++ (lib.concatMap (n: [
        "$mod, ${toString n}, workspace, ${toString n}"
        "$mod SHIFT, ${toString n}, movetoworkspace, ${toString n}"
      ]) (lib.range 1 5))
      ++ (map toHyprBind claudeBinds);

      # Media + brightness keys — GNOME's settings-daemon handled these; a bare
      # compositor doesn't. bindel = repeat while held; bindl = fire even locked.
      bindel = [
        ",XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ",XF86MonBrightnessUp, exec, brightnessctl set 5%+"
        ",XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];
      bindl = [
        ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ",XF86AudioPlay, exec, playerctl play-pause"
        ",XF86AudioNext, exec, playerctl next"
        ",XF86AudioPrev, exec, playerctl previous"
      ];
    };
  };

  # Force-overwrite hyprland.conf. If HM ever fails to place this (e.g. an
  # unrelated activation error) Hyprland boots configless and writes its own
  # STUB config as a *real* file at this path. On the next activation HM's
  # backupFileExtension="backup" dance then dies with "backup would be clobbered"
  # (the stub's own .backup already exists) — aborting the ENTIRE activation, so
  # NO home files deploy and the session comes up with default binds and no bar.
  # force=true makes HM overwrite the stub outright, breaking that trap. (Cost:
  # a hand-edited hyprland.conf would be silently replaced — acceptable, this
  # file is fully declarative.)
  xdg.configFile."hypr/hyprland.conf".force = true;

  # The bespoke bar: Quickshell package + the generated config dir. cava feeds
  # the island's audio spectrum (Spectrum.qml runs it on the default sink).
  # qml-preview is the fast-reload dev helper (see .claude/skills/qml-dial-in).
  home.packages = [
    pkgs.quickshell
    pkgs.cava
    # notify-send — the shell owns the daemon, but scripts (and bar testing)
    # still need the client.
    pkgs.libnotify
    (pkgs.writeShellScriptBin "qml-preview" (builtins.readFile ./qml-preview.sh))
  ];
  xdg.configFile."quickshell".source = qsConfig;

  # Light companions — Stylix auto-themes those with targets (autoEnable is on).
  programs.fuzzel.enable = true;
  # Notifications are owned by the Quickshell shell now (home/quickshell —
  # Notifications.qml runs the org.freedesktop.Notifications server + toasts).
  # mako is deliberately NOT enabled: only one process can own that D-Bus name,
  # so running mako would silently steal notifications from the shell.
  programs.hyprlock.enable = true;

  # Idle → lock, matching GNOME's 5-min lock (home/gnome.nix idle-delay 300).
  # hypridle does nothing without listeners, so define them: lock at 5 min,
  # screen off at 10, suspend at 20 IF on battery (AC stays awake for
  # overnight automation — the suspendOnBattery script re-implements gsd's
  # sleep-inactive-battery policy), and lock before sleep.
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };
      listener = [
        {
          timeout = 300;
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 600;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        {
          timeout = 1200;
          on-timeout = "${suspendOnBattery}";
        }
      ];
    };
  };

  # Night light — gsd's dies with GNOME. Same automatic sun schedule via
  # geoclue (system side wires the service + gammastep's authorization in
  # modules/desktop/hyprland.nix). Temperatures match GNOME night-light's
  # defaults: no filtering by day, 2700K at night.
  services.gammastep = {
    enable = true;
    provider = "geoclue2";
    temperature = {
      day = 6500;
      night = 2700;
    };
  };
  # Wallpaper: enable hyprpaper; Stylix's hyprpaper target sets the image from
  # stylix.image, so setting settings here would conflict with it.
  services.hyprpaper.enable = true;
}
