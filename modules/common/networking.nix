{ lib, ... }:

{
  # Enable NetworkManager for easy network management
  networking.networkmanager.enable = true;

  # Use systemd-resolved for DNS (caching, DNSSEC validation, DNS-over-TLS)
  # NetworkManager delegates DNS resolution to resolved automatically
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSSEC = "allow-downgrade"; # Validate DNSSEC when available, don't break if unavailable
      DNSOverTLS = "opportunistic"; # Use DNS-over-TLS when the server supports it
      FallbackDNS = [
        "1.1.1.1#cloudflare-dns.com"
        "9.9.9.9#dns.quad9.net"
      ];
    };
  };

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
      PasswordAuthentication = lib.mkDefault false; # Set to true temporarily for initial key setup
      PermitRootLogin = "no";
    };
  };
}
