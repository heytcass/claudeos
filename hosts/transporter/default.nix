{ ... }:

{
  # Dell Latitude 7280 specific configuration

  imports = [
    # Hardware configuration will be generated during install:
    # nixos-generate-config --root /mnt
    # Then copy /mnt/etc/nixos/hardware-configuration.nix here
    ./hardware-configuration.nix
  ];

  # Disko disk device: defaults to /dev/sda (SATA SSD in this machine)
  # Override in host config if different: disko.devices.disk.main.device = "/dev/sdX";

  # Machine-specific overrides
  # Boot options if needed
  # boot.kernelParams = [ ... ];

  # Network hostname (already set by mkSystem, but can override)
  # networking.hostName = "transporter";

  # Machine-specific packages
  # environment.systemPackages = with pkgs; [ ];
}
