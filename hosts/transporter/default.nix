{
  ...
}:

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

  # Walk-up complete (2026-07-05): kernel params back to the shared defaults
  # ("quiet" from boot.nix). DC/FBC run driver defaults, scx_lavd is on,
  # early KMS is on, latest kernel — every bring-up carve-out retested clean
  # after the real culprit (jasper's greeter-killing user unit) was fixed.
  # AMENDED 2026-08-03: PSR is no longer at driver default — the PSR1-on
  # default froze the panel at the static greeter ("greetd lockup" boots
  # 2026-07-12/-26/-08-03); boot.nix now sets i915.enable_psr=0 fleet-wide.

  # Walk-up step 5 (2026-07-05): scx_lavd re-enabled (shared setting from
  # modules/common/system.nix applies again). It was disabled as a possible
  # hard-lock culprit; the locks were the jasper greeter bug. If the desktop
  # wedges with a dead Caps Lock from here on, scx is the first suspect —
  # re-add `services.scx.enable = lib.mkForce false;` to isolate.

  # Boot-menu editor back to the shared locked-down default (boot.nix sets
  # editor = false) — the bring-up escape hatch is no longer needed now that
  # the machine boots reliably and is administrable over SSH.

  # Bring-up passwordless sudo removed 2026-07-07: the walk-up above is
  # complete, so wheel is back on the shared wheelNeedsPassword default.
  # The auto-update lane keeps its own scoped NOPASSWD nixos-rebuild rule
  # (modules/common/auto-update.nix) — automation is unaffected.

  # TESTBED TRIAL (tool-rethink 2026-06-12): iwd as NetworkManager's wifi
  # backend — faster scans, better roaming, WPA3, while NM keeps the GNOME
  # integration. Graduates to modules/common/networking.nix if the trial
  # holds. Note: wifi passphrases are entered fresh (no wpa_supplicant
  # profile migration — fresh install anyway).
  networking.networkmanager.wifi.backend = "iwd";

  # Hyprland + the bespoke Quickshell bar (the sole desktop since the GNOME
  # rip-out completed 2026-07-12 — see docs/plans/2026-07-11-gnome-ripout-plan.md).
  # GNOME's fallback specialisation is gone from NEW generations; pre-Phase-3
  # boot generations still carry it if a GNOME session is ever needed again.
  claude-os.hyprland.enable = true;
}
