{ lib, ... }:

{
  # Enable NetworkManager for easy network management
  networking.networkmanager.enable = true;

  # Use systemd-resolved for DNS (caching, DNSSEC validation, DNS-over-TLS)
  # NetworkManager delegates DNS resolution to resolved automatically
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSSEC = false; # Technitium handles upstream DNSSEC validation; local zones are unsigned
      DNSOverTLS = "opportunistic"; # Use DoT when server supports it, plain DNS otherwise
      LLMNR = false; # Legacy name-resolution protocol — spoofable on untrusted LANs; mDNS covers local discovery

      # No global DNS= set — NetworkManager/DHCP provides the primary DNS server,
      # preserving internal DNS resolution (e.g. local services, split-horizon DNS).
      # DoT is used opportunistically: encrypted if the server supports it, plain otherwise.

      # Fallback: public DoT-capable servers if DHCP-provided DNS is unavailable
      FallbackDNS = [
        "1.1.1.1#one.one.one.one"
        "9.9.9.9#dns.quad9.net"
      ];
    };
  };

  # Disable wait-online service (speeds up boot)
  systemd.services.NetworkManager-wait-online.enable = false;

  # Use nftables backend (modern, faster, cleaner rule syntax than iptables)
  networking.nftables.enable = true;

  # Enable firewall. SSH is opened HERE, explicitly — openssh.openFirewall
  # would otherwise open port 22 silently, making the empty list below a lie.
  # 22 is deliberately reachable on every network (roaming laptops drive each
  # other over SSH; exposure is bounded by key-only auth + modern crypto).
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
    allowedUDPPorts = [ ];
  };

  # No fail2ban: key-only sshd with a modern-crypto allowlist leaves nothing
  # for it to protect on a roaming laptop — it was a resident daemon with
  # mutable ban state (anti-ephemerality) that can ban *you* behind shared NATs

  # Enable SSH server
  services.openssh = {
    enable = true;
    # The firewall rule is declared explicitly above, not implied here
    openFirewall = false;
    settings = {
      PasswordAuthentication = false; # Disabled - using SSH keys
      PermitRootLogin = "no";

      # Restrict to modern cryptographic algorithms only
      KexAlgorithms = [
        "curve25519-sha256"
        "curve25519-sha256@libssh.org"
      ];
      Ciphers = [
        "chacha20-poly1305@openssh.com"
        "aes256-gcm@openssh.com"
        "aes128-gcm@openssh.com"
      ];
      Macs = [
        "hmac-sha2-512-etm@openssh.com"
        "hmac-sha2-256-etm@openssh.com"
      ];
    };
  };
}
