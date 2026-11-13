# VM test for "docked = wired" (modules/common/networking.nix): wifi drops
# while Ethernet is connected and must come back, unaided, on undock.
#
# That logic stranded a real machine four times (2026-07-26, 08-07, 08-24,
# 11-12) and each fix was proven only by the next real undock. This runs the
# real module, unmodified, against simulated hardware:
#
#   wifi  mac80211_hwsim gives two radios in one VM. hostapd turns the first
#         into an access point; iwd (under NetworkManager, as on the hosts)
#         drives the second as the laptop's card.
#   dock  a second virtio NIC, named en* by a udev rule so the module's own
#         `KERNEL=="en*"` removal rule sees it. The two ways a dock goes
#         away are then played back: QEMU's `set_link
#         off` (carrier drops, netdev stays: the NM dispatcher route) and a
#         PCI remove from inside the guest (netdev removed: the udev route,
#         which is what the real USB dock does).
#
# What it cannot cover: the ath10k driver, rfkill (hwsim radios have no
# Fn-key path), and suspend/resume.
#
# Run: nix build .#wifi-undock-test -L      (needs /dev/kvm)
{ pkgs, ... }:
let
  ssid = "claudeos-test";
  passphrase = "not-a-real-passphrase";
  dockMac = "52:54:00:dc:dc:01";
  dock = "enp0dock";
in
{
  name = "wifi-undock";

  nodes.machine =
    { lib, ... }:
    {
      imports = [ ../modules/common/networking.nix ];

      boot.kernelModules = [ "mac80211_hwsim" ];
      boot.extraModprobeConfig = ''
        options mac80211_hwsim radios=2
      '';

      # The dock. Slirp gives it DHCP, so NM takes it to `connected` on its
      # own default wired profile, exactly as it does with the real one.
      virtualisation.qemu.options = [
        "-netdev user,id=dock"
        "-device virtio-net-pci,netdev=dock,id=dock0,mac=${dockMac}"
      ];
      services.udev.extraRules = ''
        SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="${dockMac}", NAME="${dock}"
      '';

      # The access point, on the first radio. iwd is told to leave that phy
      # alone, and NM to leave both it and the test driver's own NIC alone:
      # a managed eth0 would read as "docked" for the whole run.
      services.hostapd = {
        enable = true;
        radios.wlan0 = {
          band = "2g";
          channel = 1;
          countryCode = "US";
          networks.wlan0 = {
            inherit ssid;
            authentication = {
              mode = "wpa2-sha256";
              wpaPassword = passphrase;
            };
          };
        };
      };
      systemd.services.iwd.serviceConfig.ExecStart = [
        ""
        "${pkgs.iwd}/libexec/iwd --nophys phy0"
      ];
      networking.networkmanager.unmanaged = [
        "interface-name:wlan0"
        "interface-name:eth*"
      ];

      # The saved home network. Static addressing: the test is about the
      # link coming back, and nothing serves DHCP on the simulated air.
      networking.networkmanager.ensureProfiles.profiles.home = {
        connection = {
          id = "home";
          type = "wifi";
        };
        wifi = {
          inherit ssid;
          mode = "infrastructure";
        };
        wifi-security = {
          key-mgmt = "wpa-psk";
          psk = passphrase;
        };
        ipv4 = {
          method = "manual";
          address1 = "192.168.99.2/24";
        };
        ipv6.method = "disabled";
      };

      # The module opens sshd; the test driver has its own back door.
      services.openssh.enable = lib.mkForce false;
    };

  testScript = ''
    def wifi_dev():
        # The AP radio is a wifi device too, just an unmanaged one.
        return machine.succeed(
            "nmcli -t -f DEVICE,TYPE,STATE device | grep ':wifi:' | grep -v ':unmanaged$' | cut -d: -f1"
        ).strip()

    def wifi_is(state, timeout):
        machine.wait_until_succeeds(
            f"nmcli -t -f DEVICE,STATE device | grep -qx '{sta}:{state}'",
            timeout=timeout,
        )

    def dock_is(state, timeout=60):
        machine.wait_until_succeeds(
            f"nmcli -t -f DEVICE,STATE device | grep -qx '${dock}:{state}'",
            timeout=timeout,
        )

    def show(label):
        print(f"--- {label}")
        print(machine.succeed("nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device"))
        print(machine.execute("journalctl -b --no-pager -u wifi-undock-reconcile -n 15")[1])

    machine.start()
    machine.wait_for_unit("NetworkManager.service")
    machine.wait_for_unit("iwd.service")
    machine.wait_for_unit("hostapd.service")
    sta = wifi_dev()
    assert sta and sta != "wlan0", f"station is {sta!r}; iwd should not own the AP radio"

    with subtest("docked at boot: wired up, wifi held down"):
        dock_is("connected")
        wifi_is("disconnected", 60)
        show("docked at boot")

    with subtest("carrier drop brings wifi back"):
        machine.send_monitor_command("set_link dock0 off")
        wifi_is("connected", 60)
        show("after carrier drop")

    with subtest("docking again drops wifi"):
        machine.send_monitor_command("set_link dock0 on")
        dock_is("connected")
        wifi_is("disconnected", 30)

    with subtest("a longer dock still reconnects"):
        # Each undock starts from a different iwd state. The one above comes
        # straight after boot, before iwd has a scan to offer, and that is the
        # one that reproduces the 2026-11-12 failure: the log shows "a valid
        # UTF-8 SSID is required" three times, then the retry getting through.
        # This one undocks after iwd has sat disconnected and idle.
        machine.sleep(90)
        machine.send_monitor_command("set_link dock0 off")
        wifi_is("connected", 60)
        show("after longer dock")

    with subtest("removing the dock NIC brings wifi back"):
        machine.send_monitor_command("set_link dock0 on")
        dock_is("connected")
        wifi_is("disconnected", 30)
        # PCI-remove the NIC from inside the guest: the netdev goes away and
        # udev sees the same `remove` a yanked USB dock produces. (QEMU's
        # device_del is ignored for a NIC on this machine type's root bus.)
        machine.succeed("echo 1 > /sys/class/net/${dock}/device/../remove")
        machine.wait_until_fails("ip link show ${dock}", timeout=30)
        wifi_is("connected", 60)
        show("after dock removal")
  '';
}
