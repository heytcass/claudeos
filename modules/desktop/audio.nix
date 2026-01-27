{ config, lib, pkgs, ... }:

{
  # Enable sound with Pipewire (modern audio server)
  # Pipewire replaces PulseAudio and JACK with better performance
  services.pulseaudio.enable = false; # Explicitly disable PulseAudio

  # Security: enable real-time scheduling for audio
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;

    # Compatibility layers for legacy applications
    alsa.enable = true;           # ALSA support
    alsa.support32Bit = true;     # 32-bit ALSA for games/Wine
    pulse.enable = true;          # PulseAudio compatibility
    jack.enable = true;           # JACK compatibility for pro audio

    # Wireplumber is the session manager for Pipewire
    wireplumber.enable = true;
  };

  # Bluetooth audio support
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false; # Don't enable Bluetooth by default (battery saving)

    settings = {
      # Better audio quality for Bluetooth devices
      General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true; # Enable experimental features for better codec support
      };
    };
  };

  # Bluetooth GUI support in GNOME
  services.blueman.enable = false; # GNOME has built-in Bluetooth settings

  # Audio tools
  environment.systemPackages = with pkgs; [
    pavucontrol  # PulseAudio Volume Control (works with Pipewire)
    helvum       # Pipewire graph patchbay (visual audio routing)
  ];
}
