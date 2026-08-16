{ pkgs, user, ... }:

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

  # The Quickshell greeter, replacing regreet (2026-08-15). Promoted to the
  # daily driver at Tom's call, ahead of the soak the greeter plan's phase 3
  # asked for — recorded here rather than left implicit.
  #
  # What made that acceptable: the two scariest items on that checklist do not
  # live in the part we replaced. The greeter's KEYMAP is cage's job (Colemak
  # arrives via XKB_DEFAULT_VARIANT in environment.sessionVariables, which
  # pam_env exports and wlroots reads) — regreet and quickshell are both merely
  # clients of cage, so swapping the client cannot change what the keyboard
  # types. Likewise the AUTH PATH is greetd's, via
  # security.pam.services.greetd.enableGnomeKeyring, which this change does not
  # touch. What genuinely remains untested is the QML behaving differently under
  # cage than under `qs -p`, and the UWSM argv.
  #
  # If the login screen is ever blank or unusable: ctrl+alt+F3 for a TTY, or
  # pick the previous generation in the boot menu (regreet is still one
  # generation away, and greetd's agreety remains available on a VT).
  claude-os.greeter.enable = true;

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

  # home-ops infrastructure health check — weekly, Sunday morning.
  #
  # Host-scoped for the same reason as the EDL rules above: the script lives in
  # ~/Projects/home-ops, which only exists on gti. transporter must not get a
  # timer pointing at a path it does not have.
  #
  # A *user* unit, defined the way every other user unit in this repo is
  # defined — `systemd.user.*` at the NixOS level (modules/apps/*,
  # modules/common/*), not home-manager. home/ carries no systemd units at all.
  #
  # Two-ring rule: the script itself stays in home-ops and is deliberately NOT
  # vendored into the store. Nix owns the *schedule and the environment* (ring
  # 1); the checks themselves are someone else's fast-moving repo (ring 2).
  #
  # THE FAILED UNIT IS THE SIGNAL. health-check.sh exits 0 when everything is
  # fine and 1 when it finds something, so `failed` means "go look" — silence is
  # the success case. Nothing here masks that: no `|| true`, no
  # SuccessExitStatus, no Restart=. Two consequences, both wanted:
  #   - claudeos-health-check's "failed user services" sweep picks it up within
  #     15 min and routes it through the normal notify path.
  #   - it is deliberately NOT added to `claude-os.selfHeal.units`. A finding
  #     here is infrastructure drift out in home-ops, never a bug in this repo's
  #     Nix — pointing the heal agent at it would have it hunt for a config
  #     cause that does not exist, and open a PR against the wrong thing.
  #
  # View results:  journalctl --user -u home-ops-health -n 50
  # Run on demand: systemctl --user start home-ops-health
  systemd.user.services.home-ops-health = {
    description = "home-ops infrastructure health check";
    # openssl is on the path explicitly so the script's nix-build fallback for
    # it never has to fire under systemd, where network and nix access are more
    # constrained than in an interactive shell.
    path = with pkgs; [
      bash
      curl
      jq
      openssl
      android-tools
      iputils
      nix
      coreutils
      gnugrep
      gnused
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/home/${user}/Projects/home-ops/scripts/health-check.sh";
      # Backstop so a hung network call cannot wedge the timer.
      TimeoutStartSec = "10m";
      SyslogIdentifier = "home-ops-health";
    };
  };

  systemd.user.timers.home-ops-health = {
    description = "Weekly home-ops health check";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun 09:00";
      # The laptop is off or asleep most Sunday mornings — catch up on the next
      # login rather than silently skipping the week.
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
  };
}
