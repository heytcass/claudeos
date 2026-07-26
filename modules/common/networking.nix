{ pkgs, ... }:

{
  # Enable NetworkManager for easy network management
  networking.networkmanager.enable = true;

  # Docked = wired: never hold two addresses on the same LAN. Dual-homing
  # wired + wifi on one subnet makes source-address selection and the strict
  # rp_filter hardening (system.nix) drop asymmetric flows — seen 2026-07-09
  # as intermittent "dial tcp i/o timeout" to GitHub while pushes worked.
  # Ethernet carrier disconnects wifi; unplugging reconnects it.
  #
  # Disconnect the device — never `nmcli radio wifi off`. The radio-off form
  # writes an rfkill *soft block*, which systemd-rfkill persists to
  # /var/lib/systemd/rfkill and restores on every subsequent boot. That turned
  # a live "we are docked" decision into sticky state: boot undocked and the
  # radio came up already blocked, and only an ethernet-down event could clear
  # it — with no ethernet present to ever produce one. Seen 2026-07-26 on
  # transporter, which booted with no usable network for 2m17s (wlan0 was ready
  # 86s before the wired link came up) and took every boot-time agent lane down
  # with it. Disconnecting drops the address and route, which is the whole
  # point of the dual-homing fix, and leaves no state behind to restore.
  #
  # -w 0 on every nmcli call: these run inside NM's dispatcher, which blocks
  # NM's state machine, so a call that waits on the very state machine it is
  # blocking would deadlock.
  networking.networkmanager.dispatcherScripts = [
    {
      type = "basic";
      source = pkgs.writeText "wired-wifi-toggle" ''
        nmcli=${pkgs.networkmanager}/bin/nmcli
        [ "$("$nmcli" -g GENERAL.TYPE device show "$1" 2>/dev/null)" = "ethernet" ] || exit 0

        # ':wifi$' deliberately excludes ':wifi-p2p' companion devices.
        wifi_devs() { "$nmcli" -t -f DEVICE,TYPE device | grep ':wifi$' | cut -d: -f1; }

        case "$2" in
          up)
            for d in $(wifi_devs); do "$nmcli" -w 0 device disconnect "$d" || true; done
            ;;
          down)
            # Reconnect only when no other wired link remains connected
            "$nmcli" -t -f TYPE,STATE device | grep -q "^ethernet:connected" && exit 0
            for d in $(wifi_devs); do "$nmcli" -w 0 device connect "$d" || true; done
            ;;
        esac
      '';
    }
  ];

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
