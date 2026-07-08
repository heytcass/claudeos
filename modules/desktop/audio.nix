{ ... }:

{
  # Enable sound with Pipewire (modern audio server)
  # Pipewire replaces PulseAudio and JACK with better performance
  services.pulseaudio.enable = false; # Explicitly disable PulseAudio

  # Security: enable real-time scheduling for audio
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;

    # Compatibility layers for legacy applications
    alsa.enable = true;
    pulse.enable = true; # PulseAudio compatibility

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

  # Audio is managed through GNOME Settings/quick-settings and wpctl
  # For advanced needs: install pavucontrol or helvum per-project via nix shell
}
