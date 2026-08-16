# home/claude-desktop.nix — supervise the Claude Desktop app as a session
# service.
#
# Why this exists: claude-desktop is not just a chat window, it is the host
# process for remote (phone) sessions — a Claude Code child is spawned under it
# (`app.slice/app-com.anthropic.Claude-*.scope`), so when the app dies, remote
# access to this machine dies with it. Until now it only ever started from the
# manual Super+C bind (`claude-quick`, modules/common/system.nix), which means
# an unattended crash left no way back in. That is fine at a desk and useless
# while travelling.
#
# Scope note: this recovers from the app *crashing*. It cannot recover from a
# reboot — the unit is bound to graphical-session.target, which only exists once
# someone logs in, and there is deliberately no autologin (see PHILOSOPHY.md's
# security posture). A reboot while away still means no remote access.
{
  inputs,
  pkgs,
  ...
}:

let
  claudeDesktop =
    inputs.claude-desktop-linux.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop;
in
{
  systemd.user.services.claude-desktop = {
    Unit = {
      Description = "Claude Desktop (supervised — hosts remote/phone sessions)";

      # graphical-session.target is activated by UWSM, NOT by the plain
      # "Hyprland" session entry — the same load-bearing choice documented in
      # home/hyprland.nix for hyprpaper/hypridle/gammastep. Logging in via the
      # wrong greeter entry strands this unit exactly like those three.
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];

      # Never stop trying. systemd's default rate limit (5 starts / 10s) would
      # mark the unit failed and give up permanently after a short crash loop —
      # which is precisely the silent, unrecoverable stranding this unit exists
      # to prevent. Same reasoning, same knob as the wifi-undock-reconcile unit
      # in modules/common/networking.nix.
      StartLimitIntervalSec = 0;
    };

    Service = {
      # The bin wrapper injects the Wayland flags (--ozone-platform-hint=auto,
      # GlobalShortcutsPortal, text-input-v3); calling lib/claude-desktop
      # directly would silently drop them.
      ExecStart = "${claudeDesktop}/bin/claude-desktop";

      # Restart policy — the one real judgement call in this file.
      #
      # "always" maximises uptime, which is the whole point while travelling: it
      # restarts on a clean exit too, so nothing short of stopping the unit
      # takes remote access down.
      #
      # The cost, worth knowing before you change it: the app is single-instance
      # (SingleMainWindow=true — a second launch just focuses the first and
      # exits 0). So if an instance is ALREADY running outside this unit when it
      # starts, the unit's own process exits 0 immediately and "always" restarts
      # it every RestartSec, forever. That only bites when starting the unit on
      # top of a hand-launched instance; at login there is nothing to collide
      # with. The alternative, "on-failure", is immune to that loop and respects
      # a deliberate Quit — at the price of staying down if the app ever exits 0
      # for a bad reason.
      Restart = "always";
      RestartSec = 5;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
