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

  # Niri reads its keyboard layout from home/niri.nix (input.keyboard.xkb);
  # there is no X server, so services.xserver.xkb would be dead config here.
}
