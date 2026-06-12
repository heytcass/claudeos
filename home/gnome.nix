# home/gnome.nix — GNOME user configuration via dconf.
# Ports the Claude keybindings that lived in the old Niri config; everything
# else (idle, lock, displays, clipboard) is GNOME's own machinery now.
{ lib, ... }:

let
  inherit (lib.hm.gvariant) mkTuple mkUint32;
in
{
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

    # Idle + lock: blank at 5 min, lock immediately on blank
    "org/gnome/desktop/session" = {
      idle-delay = mkUint32 300;
    };
    "org/gnome/desktop/screensaver" = {
      lock-enabled = true;
      lock-delay = mkUint32 0;
    };

    # Claude keybindings (ported from Niri: Mod+C / Mod+A / Mod+Shift+A / Mod+Ctrl+A)
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/"
      ];
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      name = "Claude quick terminal";
      binding = "<Super>c";
      command = "claude-quick";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
      name = "Ask Claude";
      binding = "<Super>a";
      command = "claude-ask-desktop";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
      name = "Claude screenshot analysis";
      binding = "<Super><Shift>a";
      command = "claude-screenshot";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3" = {
      name = "Claude screenshot analysis (interactive)";
      binding = "<Super><Ctrl>a";
      command = "claude-screenshot-interactive";
    };
  };
}
