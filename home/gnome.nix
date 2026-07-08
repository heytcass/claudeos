# home/gnome.nix — GNOME user configuration via dconf.
# Ports the Claude keybindings that lived in the old Niri config; everything
# else (idle, lock, displays, clipboard) is GNOME's own machinery now.
{ lib, pkgs, ... }:

let
  inherit (lib.hm.gvariant) mkTuple mkUint32;

  # Claude keybindings (ported from Niri: Mod+C / Mod+A / Mod+Shift+A /
  # Mod+Ctrl+A). The dconf path list and per-binding entries below are
  # generated from this list — add a binding here, done.
  # NOTE: home/claudeos-help.nix hand-lists these for the user; keep it in sync.
  claudeKeybindings = [
    {
      name = "Claude quick terminal";
      binding = "<Super>c";
      command = "claude-quick";
    }
    {
      name = "Ask Claude";
      binding = "<Super>a";
      command = "claude-ask-desktop";
    }
    {
      name = "Claude screenshot analysis";
      binding = "<Super><Shift>a";
      command = "claude-screenshot";
    }
    {
      name = "Claude screenshot analysis (interactive)";
      binding = "<Super><Ctrl>a";
      command = "claude-screenshot-interactive";
    }
  ];

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
    };

    # Enable the AppIndicator/StatusNotifier extension so tray icons have a
    # host (GNOME has no system tray by default). The extension package is
    # installed system-side in modules/desktop/gnome.nix.
    "org/gnome/shell" = {
      disable-user-extensions = false;
      enabled-extensions = [ "appindicatorsupport@rgcjonas.gmail.com" ];
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
    lib.imap0 (i: binding: lib.nameValuePair (keybindingPath i) binding) claudeKeybindings
  );
}
