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
      DNSOverTLS = "no"; # Disabled - caused slow DNS lookups with non-DoT servers
      FallbackDNS = [
        "1.1.1.1"
        "9.9.9.9"
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

  # Brute-force protection for SSH
  services.fail2ban = {
    enable = true;
    maxretry = 3;
    bantime = "1h";
    jails.sshd = {
      settings = {
        filter = "sshd[mode=aggressive]";
        maxretry = 3;
        bantime = "24h";
      };
    };
  };

  # Enable SSH server
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false; # Disabled - using SSH keys
      PermitRootLogin = "no";
    };
  };
}
