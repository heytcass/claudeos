{ pkgs, ... }:

let
  # Reconcile the wifi radio to the current wired-carrier state: enable it
  # whenever no Ethernet link is connected. Runs on boot, on resume, and — via
  # the udev rule below — whenever a wired interface is *removed*, which is the
  # undock path that stranded the radio for 18 minutes on 2026-08-07.
  #
  # Two things it has to survive:
  #
  # 1. The dock's Ethernet lingers in NM as `connected` for seconds after the
  #    bus teardown starts (2026-08-07: rfkill block at 08:28:09, xhci remove
  #    at 08:28:14). A single carrier check races that and wrongly concludes
  #    "still docked", so re-check across ~15s. Bail the instant no carrier is
  #    seen — a cold boot undocked must not sit blind for 15s waiting.
  #
  # 2. `nmcli radio wifi on` alone is not enough. The 2026-08-07 block was set
  #    from outside NetworkManager — WLAN and Bluetooth flipped in the same
  #    instant with no `op=radio-control` audit record, 5s ahead of the PCIe
  #    teardown — so clear the soft block directly rather than assuming NM
  #    considers it its own to lift.
  #
  # Only ever turns the radio *on*, so it cannot reintroduce dual-homing.
  wifiUndockReconcile = pkgs.writeShellScript "wifi-undock-reconcile" ''
    nmcli=${pkgs.networkmanager}/bin/nmcli
    rfkill=${pkgs.util-linux}/bin/rfkill

    docked() {
      "$nmcli" -t -f TYPE,STATE device \
        | ${pkgs.gnugrep}/bin/grep -q '^ethernet:connected'
    }

    # Distinguish a deliberate Fn+Home from stranded state. The kernel's
    # rfkill-input handler (bound straight to "Dell WMI hotkeys" / "Intel HID
    # events") blocks every radio on KEY_RFKILL, and systemd-rfkill stamps the
    # saved-state file each time that changes. A block set within the last 5
    # minutes reads as an intentional press and is left alone; an older one is
    # stale state — exactly what strands a machine that powered off docked and
    # booted undocked — and gets healed.
    recently_blocked() {
      # systemd-rfkill stamps the file on *every* transition, unblocks included,
      # so the timestamp alone only says "recently changed". Require the radio
      # to actually be blocked right now for the guard to mean what it claims.
      "$rfkill" list wlan | ${pkgs.gnugrep}/bin/grep -q 'Soft blocked: yes' || return 1

      now=$(${pkgs.coreutils}/bin/date +%s)
      newest=$(${pkgs.coreutils}/bin/stat -c %Y /var/lib/systemd/rfkill/*:wlan 2>/dev/null \
        | ${pkgs.coreutils}/bin/sort -n | ${pkgs.coreutils}/bin/tail -n1)
      [ -n "$newest" ] && [ $((now - newest)) -lt 300 ]
    }

    for _ in 1 2 3 4 5; do
      if ! docked; then
        # Fresh press wins: leave the radio exactly as the user set it.
        recently_blocked && exit 0
        "$rfkill" unblock wlan || true
        "$nmcli" radio wifi on || true
        exit 0
      fi
      ${pkgs.coreutils}/bin/sleep 3
    done

    # Wired carrier still up after ~15s: genuinely docked, leave the radio off.
    exit 0
  '';
in
{
  # Enable NetworkManager for easy network management
  networking.networkmanager.enable = true;

  # Scan with the real MAC. NixOS defaults this on, and on the QCA6174
  # (ath10k, "Killer 1435") per-scan MAC randomization is a known way to wedge
  # the scan state machine: 2026-08-07 08:21:46–08:27:20 the radio was up and
  # willing but every scan died as "Reject scan trigger since one is already
  # pending" — six minutes, not one completed scan, no network list to pick
  # from. The privacy this buys is narrow (it randomizes probe requests only,
  # not the associated MAC, which `wifi.cloned-mac-address=preserve` already
  # pins to the hardware address anyway), so it is not worth a radio that
  # cannot find an AP.
  networking.networkmanager.wifi.scanRandMacAddress = false;

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
        type=$("$nmcli" -g GENERAL.TYPE device show "$1" 2>/dev/null) || type=""

        # ':wifi$' deliberately excludes ':wifi-p2p' companion devices.
        wifi_devs() { "$nmcli" -t -f DEVICE,TYPE device | grep ':wifi$' | cut -d: -f1; }

        case "$2" in
          up)
            [ "$type" = "ethernet" ] || exit 0
            for d in $(wifi_devs); do "$nmcli" -w 0 device disconnect "$d" || true; done
            ;;
          down)
            # An empty type is not a reason to bail here. The dock's wired NIC is
            # a USB r8152: undocking *removes* the netdev rather than dropping
            # carrier, so by dispatcher time NM answers `Device not found` (exit
            # 10, empty stdout) and the old `= "ethernet"` guard exited before
            # ever reaching the reconnect below. That is the undock path, not a
            # foreign event — a device that still exists still reports its type,
            # so wifi's own down events are still filtered out normally.
            [ "$type" = "ethernet" ] || [ -z "$type" ] || exit 0

            # Reconnect only when no other wired link remains connected
            "$nmcli" -t -f TYPE,STATE device | grep -q "^ethernet:connected" && exit 0
            for d in $(wifi_devs); do "$nmcli" -w 0 device connect "$d" || true; done
            ;;
        esac
      '';
    }
  ];

  # Heal the persisted `radio wifi off` from wired-wifi-toggle. That toggle only
  # re-enables wifi on an Ethernet "down" event, which never fires if the machine
  # powers off or suspends while docked and then starts up undocked. Reconcile
  # once on boot (after NetworkManager) and again on resume from suspend.
  systemd.services.wifi-undock-reconcile = {
    description = "Re-enable wifi when undocked (heals wired-wifi-toggle persistence)";
    after = [ "NetworkManager.service" ];
    wants = [ "NetworkManager.service" ];
    wantedBy = [ "multi-user.target" ];
    # A dock carries several wired interfaces (2026-08-07: three `en*` removals
    # inside one second), so the udev rule below fires several restarts back to
    # back. Without lifting the limit they trip systemd's default start-limit
    # and the one that matters gets refused.
    startLimitIntervalSec = 0;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${wifiUndockReconcile}";
    };
  };

  # Boot and resume are not enough. NetworkManager emits no dispatcher "down"
  # event when a dock's wired interface is *removed* rather than merely losing
  # carrier — on 2026-08-07 no nm-dispatcher run happened at the 08:28:14
  # teardown at all — so the wired-wifi-toggle above never fired and nothing
  # healed the radio until the dock was plugged back in 18 minutes later.
  # Catch the removal at the udev layer, where it is unmissable.
  #
  # --no-block matters: the reconcile can take ~15s and a udev worker that
  # blocks that long stalls the rest of the undock teardown.
  services.udev.extraRules = ''
    ACTION=="remove", SUBSYSTEM=="net", KERNEL=="en*", RUN+="${pkgs.systemd}/bin/systemctl --no-block restart wifi-undock-reconcile.service"
  '';

  powerManagement.resumeCommands = "${wifiUndockReconcile}";

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
