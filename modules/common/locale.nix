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

  # Tom's GNOME session reads its layout from dconf (home/gnome.nix
  # input-sources) — but the GDM GREETER cannot see user dconf and falls back
  # to the system xkb default, which showed up as QWERTY at the login screen
  # on transporter's fresh install (2026-07-05). Set the system default to
  # Colemak so GDM matches the session. (accountsservice papers over this
  # after the first login on long-lived installs, which is why it went
  # unnoticed before.)
  services.xserver.xkb = {
    layout = "us";
    variant = "colemak";
  };
}
