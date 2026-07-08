# home/gnome.nix — GNOME user configuration via dconf.
# Ports the Claude keybindings that lived in the old Niri config; everything
# else (idle, lock, displays, clipboard) is GNOME's own machinery now.
{ lib, pkgs, ... }:

let
  inherit (lib.hm.gvariant) mkTuple mkUint32;

  # Claude keybindings come from the shared source of truth — the help
  # screen (home/claudeos-help.nix) is generated from the same list, so the
  # two can no longer drift. The dconf path list and per-binding entries
  # below are generated from it: add a binding in lib/keybindings.nix, done.
  claudeKeybindings = import ../lib/keybindings.nix;

  keybindingPath =
    i: "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom${toString i}";
in
{
  # Qt apps follow the GNOME dark theme via the adwaita platform theme.
  # Owned here (not modules/desktop/theme.nix): the NixOS qt module only has
  # legacy platform plugins, and Stylix's Qt target doesn't support GNOME
  # (it warns and emits the deprecated platformTheme "gnome"), so it's off.
  stylix.targets.qt.enable = false;
  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style = {
      name = "adwaita-dark";
      package = with pkgs; [
        adwaita-qt
        adwaita-qt6
      ];
    };
  };

  # Shell extensions, declaratively (this module owns the enabled-extensions
  # dconf key — don't also set it by hand below):
  # - appindicator: tray icon host (GNOME ships no system tray; Claude
  #   Desktop and friends need somewhere to render)
  # - caffeine: one-click idle-lock inhibit — long agent runs must not get
  #   locked mid-flight (the 5-min idle lock below is aggressive on purpose)
  programs.gnome-shell = {
    enable = true;
    extensions = [
      { package = pkgs.gnomeExtensions.appindicator; }
      { package = pkgs.gnomeExtensions.caffeine; }
    ];
  };

  dconf.settings = {
    # Colemak everywhere (console keymap lives in modules/common/locale.nix)
    "org/gnome/desktop/input-sources" = {
      sources = [
        (mkTuple [
          "xkb"
          "us+colemak"
        ])
      ];
    };

    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      show-battery-percentage = true;
      clock-show-weekday = true;
    };

    # Touchpad: GNOME ships tap-to-click OFF — a daily papercut on laptops
    "org/gnome/desktop/peripherals/touchpad" = {
      tap-to-click = true;
      two-finger-scrolling-enabled = true;
    };

    # Faster key repeat for a terminal-heavy workflow (defaults: 500/30)
    "org/gnome/desktop/peripherals/keyboard" = {
      delay = mkUint32 250;
      repeat-interval = mkUint32 25;
    };

    # Fractional scaling (125%/150% in Settings) — matters on gti's HiDPI
    # 13" panel; harmless on transporter's 1080p
    "org/gnome/mutter" = {
      experimental-features = [ "scale-monitor-framebuffer" ];
    };

    # Night light: warm the screen on the local sun schedule
    "org/gnome/settings-daemon/plugins/color" = {
      night-light-enabled = true;
      night-light-schedule-automatic = true;
    };

    # Power: on AC stay awake — overnight automation (auto-update, diary,
    # morning desk) needs the plugged-in machine running while nobody's
    # logged in. On battery, suspend after 20 min idle.
    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-type = "nothing";
      sleep-inactive-battery-type = "suspend";
      sleep-inactive-battery-timeout = 1200;
      power-button-action = "suspend";
    };

    # Idle + lock: blank at 5 min, lock immediately on blank
    "org/gnome/desktop/session" = {
      idle-delay = mkUint32 300;
    };
    "org/gnome/desktop/screensaver" = {
      lock-enabled = true;
      lock-delay = mkUint32 0;
    };

    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = lib.imap0 (i: _: "/${keybindingPath i}/") claudeKeybindings;
    };
  }
  // lib.listToAttrs (
    lib.imap0 (
      i: b:
      lib.nameValuePair (keybindingPath i) {
        # Only the dconf-schema keys — display/help are for the help screen
        inherit (b) name binding command;
      }
    ) claudeKeybindings
  );
}
