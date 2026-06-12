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

  # Console keymap (TTY)
  console = {
    font = "Lat2-Terminus16";
    keyMap = "colemak";
  };

  # GNOME reads its keyboard layout from dconf (home/gnome.nix input-sources);
  # services.xserver.xkb is not needed for the Wayland session.
}
