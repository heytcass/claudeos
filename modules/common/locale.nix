{ lib, ... }:

let
  defaultLocale = "en_US.UTF-8";
in
{
  # Timezone
  time.timeZone = lib.mkDefault "America/New_York";

  # Internationalization
  i18n.defaultLocale = defaultLocale;

  i18n.extraLocaleSettings = lib.genAttrs [
    "LC_ADDRESS"
    "LC_IDENTIFICATION"
    "LC_MEASUREMENT"
    "LC_MONETARY"
    "LC_NAME"
    "LC_NUMERIC"
    "LC_PAPER"
    "LC_TELEPHONE"
    "LC_TIME"
  ] (_: defaultLocale);

  # Console keymap (TTY). The graphical layers get Colemak elsewhere: the
  # Hyprland session via its input config (home/hyprland.nix) and the regreet
  # greeter via XKB_DEFAULT_* pam_env vars (modules/desktop/hyprland.nix).
  # The old GDM-greeter services.xserver.xkb workaround died with GNOME
  # (Phase 3, 2026-07-12).
  console = {
    font = "Lat2-Terminus16";
    keyMap = "colemak";
  };
}
