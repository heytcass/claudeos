{ ... }:

{
  # Dell Latitude 7280 specific configuration

  imports = [
    # Hardware configuration will be generated during install:
    # nixos-generate-config --root /mnt
    # Then copy /mnt/etc/nixos/hardware-configuration.nix here
    ./hardware-configuration.nix
  ];

  # Machine-specific overrides
  # Boot options if needed
  # boot.kernelParams = [ ... ];

  # Network hostname (already set by mkSystem, but can override)
  # networking.hostName = "transporter";

  # Machine-specific packages
  # environment.systemPackages = with pkgs; [ ];
}
