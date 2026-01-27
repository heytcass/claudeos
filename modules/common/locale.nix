{ config, lib, pkgs, ... }:

{
  # Timezone
  time.timeZone = lib.mkDefault "America/New_York"; # Change as needed

  # Internationalization
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Console keymap (TTY)
  console = {
    font = "Lat2-Terminus16";
    keyMap = "colemak";
  };

  # X11/Wayland keyboard layout
  services.xserver.xkb = {
    layout = "us";
    variant = "colemak";
  };
}
