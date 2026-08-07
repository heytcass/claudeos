{ pkgs, ... }:

{
  # Dell XPS 13 9370 specific configuration

  imports = [
    ./hardware-configuration.nix
  ];

  # Disko disk device for this machine (NVMe SSD)
  disko.devices.disk.main.device = "/dev/nvme0n1";

  # Hyprland desktop — flipped in-repo 2026-07-12 (Phase 3 deleted GNOME
  # entirely; this host was awaiting reinstall and lands directly on the
  # Hyprland stack at its next rebuild/reinstall). One host-specific watch
  # item for first boot: the 13" HiDPI panel wants a per-monitor fractional
  # scale (`monitor = eDP-1, preferred, auto, 1.5` or similar in
  # home/hyprland.nix or a host override) — burn-in checklist covers it.
  claude-os.hyprland.enable = true;

  # Machine-specific overrides (Phase 5)

  # Lenovo ThinkSmart View flashing (tsv-fleet project, runbook at
  # ~/Projects/tsv-fleet/tsv-fleet-runbook.md). gti is the only host that
  # physically flashes these, so this stays out of modules/common/.
  #
  # 05c6:9008 is Qualcomm's EDL / "QDLoader 9008" emergency-download mode — the
  # state the board enumerates in when you short the test point. Two rules,
  # doing two different jobs:
  #
  #   uaccess              hands the device to whoever owns the active local
  #                        session, via logind. Deliberately NOT MODE="0666":
  #                        that was in the original snippet, but it is both
  #                        redundant with uaccess and strictly broader — it
  #                        would make the port world-read/write for every
  #                        account and daemon on the box, not just the person
  #                        sitting at it.
  #
  #   ID_MM_DEVICE_IGNORE  keeps ModemManager's hands off the serial port. This
  #                        is THE classic Linux EDL failure: MM probes any new
  #                        serial device with AT commands, and those bytes land
  #                        mid-handshake and wedge the flash. Symptom is a
  #                        transfer that dies seconds in for no stated reason.
  #                        Belt-and-braces: ModemManager already ships the same
  #                        ignore for 05c6:9008 in its own 80-mm-candidate.rules,
  #                        but stating it here keeps the guarantee ours rather
  #                        than a detail of whatever MM version comes down the
  #                        next flake update.
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="05c6", ATTR{idProduct}=="9008", TAG+="uaccess"
    ATTRS{idVendor}=="05c6", ATTRS{idProduct}=="9008", ENV{ID_MM_DEVICE_IGNORE}="1"
  '';

  # adb over both USB and network for the flashed devices.
  #
  # NOT `programs.adb.enable` — that option was REMOVED from nixpkgs and now
  # trips a build assertion ("no longer has any effect; please remove it").
  # systemd 258+ applies the uaccess rules the module used to install, so all
  # that is left is the binary. Caught by `nix flake check` 2026-08-06.
  #
  # The now-gone module was also what created the `adbusers` group, so there is
  # no adbusers membership to add — adding one would fail on an undefined group.
  # The shared list in modules/common/users.nix already carries "dialout" for
  # serial access, which is the part that still matters here.
  environment.systemPackages = [ pkgs.android-tools ];
}
