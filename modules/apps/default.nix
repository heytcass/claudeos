{ lib, pkgs, ... }:

{
  imports = [
    ./terminals.nix
    ./claude.nix
    ./jasper.nix
    ./mcp-system-health
    ./claude-monitor
    ./morning-desk.nix
    ./cards.nix
    ./intent.nix
    ./contexts
  ];

  # Enable Claude and Jasper by default (override per-host with `false`)
  claude-os.claude.enable = lib.mkDefault true;
  # Jasper is now a ClaudeOS lane, not the old Rust daemon (docs/PHILOSOPHY.md
  # "On Jasper specifically" — take the thinking, not the daemon). It rides the
  # Claude subscription (no dedicated API key) and writes a gated insight for
  # the bar; cheap to leave on.
  claude-os.jasper.enable = lib.mkDefault true;
  # Who's-who / relationships live in an untracked local file (this repo is
  # public). Missing file = section silently skipped, so this is safe to set
  # on hosts that haven't written one yet.
  claude-os.jasper.personalContextFile = lib.mkDefault "/home/tom/.config/jasper-companion/context.md";
  claude-os.monitor.enable = lib.mkDefault true;
  claude-os.monitor.dailyBrief = lib.mkDefault true;
  claude-os.monitor.journalDiary = lib.mkDefault true;
  claude-os.morningDesk.enable = lib.mkDefault true;

  # Applications (direct installs — no extra configuration needed)
  # Communication apps (Slack, Discord, Teams) are deliberately NOT packaged:
  # they're fast-moving Electron wrappers around web apps — ring 2. Install
  # them as Chrome PWAs (chrome://apps) so they auto-update and add zero
  # closure weight. (Discord-in-nixpkgs famously refuses to launch until the
  # package catches its forced updates — the exact treadmill the two-ring
  # rule exists to avoid.)
  environment.systemPackages = with pkgs; [
    google-chrome # Browser (also hosts the comms PWAs)
    obsidian # Knowledge management (install Terminal + Web Clipper community plugins)
  ];
}
