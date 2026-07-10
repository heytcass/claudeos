# home/hyprland.nix — Hyprland + a bespoke Quickshell bar, per-user config.
# Imported ONLY inside hosts/transporter's `hyprland` specialisation, so it is
# entirely absent on the default GNOME generation and on gti. All colors come
# from the Stylix base16 palette (never hardcoded hex) — CLAUDE.md mandate.
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
  toHyprBind =
    b:
    let
      tokens = lib.filter (s: s != "") (
        lib.splitString ">" (lib.replaceStrings [ "<" ] [ "" ] b.binding)
      );
      mods = lib.init tokens; # everything but the last token is a modifier
      key = lib.toUpper (lib.last tokens);
      hyprMods = lib.concatStringsSep " " (map (m: modMap.${m} or (lib.toUpper m)) mods);
    in
    "${hyprMods}, ${key}, exec, ${b.command}";

  # Assemble the Quickshell config dir: the static QML from ./quickshell plus a
  # Colors.qml singleton generated from the live Stylix palette. A directory
  # `.source` symlink can't have a file added inside it, so build the dir in a
  # derivation instead.
  qsConfig = pkgs.runCommand "claudeos-quickshell" { } ''
    mkdir -p "$out"
    cp -r ${./quickshell}/. "$out/"
    cat > "$out/Colors.qml" <<'EOF'
    pragma Singleton
    import Quickshell
    import QtQuick

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
    }
    EOF
  '';
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    # UWSM owns the session (system module sets programs.hyprland.withUWSM);
    # don't also let home-manager start a hyprland systemd target.
    systemd.enable = false;

    settings = {
      "$mod" = "SUPER";
      "$terminal" = "ghostty";
      "$launcher" = "fuzzel";

      exec-once = [
        "qs" # the bespoke Quickshell bar
        "hyprpaper"
        "hypridle"
      ];

      general = {
        border_size = 2;
        gaps_in = 4;
        gaps_out = 8;
        "col.active_border" = "rgba(${c.base0D}ff)"; # terracotta
        "col.inactive_border" = "rgba(${c.base03}aa)";
      };

      decoration.rounding = 8;

      bind = [
        "$mod, Return, exec, $terminal"
        "$mod, Q, killactive,"
        "$mod, Space, exec, $launcher"
        "$mod, L, exec, hyprlock"
        "$mod, V, togglefloating,"
        "$mod, F, fullscreen,"
        "$mod, J, movefocus, l"
        "$mod, SEMICOLON, movefocus, r"
      ]
      ++ (lib.concatMap (n: [
        "$mod, ${toString n}, workspace, ${toString n}"
        "$mod SHIFT, ${toString n}, movetoworkspace, ${toString n}"
      ]) (lib.range 1 5))
      ++ (map toHyprBind claudeBinds);
    };
  };

  # The bespoke bar: Quickshell package + the generated config dir.
  home.packages = [ pkgs.quickshell ];
  xdg.configFile."quickshell".source = qsConfig;

  # Light companions — Stylix auto-themes those with targets (autoEnable is on).
  programs.fuzzel.enable = true;
  services.mako.enable = true;
  programs.hyprlock.enable = true;
  services.hypridle.enable = true;
  services.hyprpaper = {
    enable = true;
    settings = {
      preload = [ "${osConfig.stylix.image}" ];
      wallpaper = [ ",${osConfig.stylix.image}" ];
    };
  };
}
