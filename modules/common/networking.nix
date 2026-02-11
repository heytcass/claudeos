{ lib, ... }:

{
  # Enable NetworkManager for easy network management
  networking.networkmanager.enable = true;

  # Disable wait-online service (speeds up boot)
  systemd.services.NetworkManager-wait-online.enable = false;

  # Enable firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ ]; # Add ports as needed
    allowedUDPPorts = [ ];
  };

  # Enable SSH server
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = lib.mkDefault true; # Disable after key setup
      PermitRootLogin = "no";
    };
  };
}
