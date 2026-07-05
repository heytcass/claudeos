{ lib, pkgs, ... }:

{
  # Dell Latitude 7280 — TESTBED host for the ClaudeOS return.
  # Purpose: prove the integration story (Claude desktop app, Chrome extension
  # native messaging, VSCode, file pickers/drag-and-drop, MCP experimentation)
  # on real hardware before gti is reinstalled.
  #
  # First-install checklist (see docs/SECRETS.md for details):
  #   1. After install, derive this host's age key:
  #        nix shell nixpkgs#ssh-to-age -c ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
  #   2. Add it to .sops.yaml as &transporter_host and run
  #        sops updatekeys secrets/secrets.yaml
  #      Until then, sops secrets won't decrypt here (jasper will stay down).

  imports = [
    ./hardware-configuration.nix
  ];

  # Disko disk device for this machine (SATA SSD)
  disko.devices.disk.main.device = "/dev/sda";

  # Kernel history on this Latitude 7280 (Kaby Lake, 2017) — REWRITTEN
  # 2026-07-05 after the fresh install: the "hard locks at the display
  # handoff" (6.18, and initially 6.12) were NEVER the kernel. They were
  # jasper's user unit pulling graphical-session.target active in GDM's
  # greeter sessions, killing the greeter in a loop — black screen, stuck
  # VT, dead-looking keyboard, while journald kept logging underneath
  # (fixed in modules/apps/jasper.nix). 6.12 + that fix boots to a working
  # desktop (proven 2026-07-05, BIOS 1.36.0).
  #
  # Still unexplained: linuxPackages_latest (7.0.x) locking ~3 lines into
  # EARLY boot (pre-userspace, 2026-06-16) — that predates any greeter and
  # deserves a retrial now that late failures can't be misattributed.
  #
  # WALK-UP: 6.12 proven 2026-07-05, 6.18.34 proven same day (clean boot,
  # no failed units — the "6.18 display-handoff lock" was the jasper bug).
  # Pin now dropped → linuxPackages_latest (boot.nix default), retrying the
  # one genuinely unexplained failure: 7.0.x locking ~3 lines into early
  # boot on 2026-06-16. If that reproduces, re-pin pkgs.linuxPackages (6.18)
  # and investigate 7.0-vs-Kaby-Lake specifically (BIOS 1.36.0 is current).

  # Early KMS (i915 in stage-1 initrd, from the nixos-hardware
  # dell-latitude-7280 profile) re-enabled 2026-07-05 — walk-up step 3.
  # It was deferred to stage 2 during bring-up so a display-handoff failure
  # would land in the on-disk journal; that forensic window is what proved
  # the "locks" were the jasper greeter bug, not i915. This reboot is the
  # true retrial of the 2026-06-16 "7.0 locks 3 lines in" report (which
  # happened WITH early KMS): if it reproduces, restore
  # `hardware.intelgpu.loadInInitrd = false;` and investigate i915-in-initrd
  # on 7.0.x specifically.

  # Walk-up step 4 (2026-07-05): i915 PSR/DC/FBC restored to driver defaults —
  # they were disabled as suspected Kaby Lake hang culprits, but the "hangs"
  # turned out to be the jasper greeter bug, so the power savings return.
  # sysrq stays (and "quiet" stays dropped) until the last cleanup reboot:
  # if PSR/DC/FBC do misbehave on this panel, we want the console evidence
  # and the SysRq escape hatch one more time. Final state: drop this whole
  # mkForce (shared boot.nix "quiet" returns) once A+B prove stable.
  boot.kernelParams = lib.mkForce [
    "sysrq_always_enabled=1"
  ];

  # Walk-up step 5 (2026-07-05): scx_lavd re-enabled (shared setting from
  # modules/common/system.nix applies again). It was disabled as a possible
  # hard-lock culprit; the locks were the jasper greeter bug. If the desktop
  # wedges with a dead Caps Lock from here on, scx is the first suspect —
  # re-add `services.scx.enable = lib.mkForce false;` to isolate.

  # BRING-UP ONLY: boot.nix sets systemd-boot.editor = false, which blocks
  # editing the kernel cmdline at the boot menu — forcing a full USB rescue
  # cycle for every kernel-param experiment. Re-enable the editor here so we
  # can test params (nomodeset, individual i915 flags) live by pressing `e` at
  # the systemd-boot menu. SECURITY NOTE: this lets anyone at the keyboard pass
  # arbitrary kernel params (e.g. init=/bin/sh) — acceptable on a testbed mid
  # bring-up; REVERT (drop this line) once the machine boots reliably.
  boot.loader.systemd-boot.editor = lib.mkForce true;

  # TESTBED: passwordless sudo for wheel so kernel walk-up rebuilds/reboots
  # can be driven over SSH from gti without a human at the keyboard
  # (per the decided autonomy-over-hardening trade-off in PHILOSOPHY.md).
  # Revisit when transporter graduates from bring-up.
  security.sudo-rs.wheelNeedsPassword = false;

  # TESTBED TRIAL (tool-rethink 2026-06-12): iwd as NetworkManager's wifi
  # backend — faster scans, better roaming, WPA3, while NM keeps the GNOME
  # integration. Graduates to modules/common/networking.nix if the trial
  # holds. Note: wifi passphrases are entered fresh (no wpa_supplicant
  # profile migration — fresh install anyway).
  networking.networkmanager.wifi.backend = "iwd";
}
