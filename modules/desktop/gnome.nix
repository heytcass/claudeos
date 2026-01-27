{ config, lib, pkgs, ... }:

{
  # Enable X server (required for display managers)
  services.xserver.enable = true;

  # Exclude xterm (pulled in by X server dependencies)
  services.xserver.excludePackages = with pkgs; [
    xterm
  ];

  # Use GDM display manager (GNOME's native DM)
  services.displayManager.gdm = {
    enable = true;
    wayland = true; # Wayland by default, fallback to X11 available
  };

  # Enable GNOME Desktop Environment
  services.desktopManager.gnome.enable = true;

  # Disable X11 forwarding over SSH for security
  services.openssh.settings.X11Forwarding = lib.mkDefault false;

  # Core GNOME packages
  environment.systemPackages = with pkgs; [
    # Essential GNOME tools
    gnome-tweaks           # Advanced GNOME settings
    gnome-extension-manager # Manage GNOME extensions

    # Extensions for enhanced functionality
    gnomeExtensions.appindicator           # Tray icons support
    gnomeExtensions.just-perfection        # Customize GNOME UI
    gnomeExtensions.caffeine               # Prevent screen sleep
  ];

  # Exclude unwanted GNOME apps to keep system lean
  environment.gnome.excludePackages = with pkgs; [
    epiphany       # GNOME Web (we'll use Chrome)
    geary          # Email client
    gnome-contacts
    gnome-maps
    gnome-music
    gnome-photos
    gnome-tour     # First-run tour
    gnome-weather
    totem          # Video player
    yelp           # Help browser
    gnome-console  # GNOME terminal (we'll use WezTerm)
  ];

  # Enable GVfs for virtual filesystems (Trash, network shares, etc.)
  services.gvfs.enable = true;

  # Enable GNOME keyring for credential storage
  services.gnome.gnome-keyring.enable = true;

  # Enable accounts daemon for online accounts
  services.gnome.gnome-online-accounts.enable = true;

  # Automatic problem reporting (disabled for privacy)
  environment.sessionVariables = {
    GNOME_SHELL_CRASHREPORTER_ENABLED = "false";
  };

}
