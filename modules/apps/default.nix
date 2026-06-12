{ lib, pkgs, ... }:

{
  imports = [
    ./terminals.nix
    ./claude.nix
    ./jasper.nix
    ./mcp-system-health
    ./claude-monitor
    ./morning-desk.nix
  ];

  # Enable Claude and Jasper by default (override per-host with `false`)
  claude-os.claude.enable = lib.mkDefault true;
  claude-os.jasper.enable = lib.mkDefault true;
  claude-os.monitor.enable = lib.mkDefault true;
  claude-os.monitor.dailyBrief = lib.mkDefault true;
  claude-os.monitor.journalDiary = lib.mkDefault true;
  claude-os.morningDesk.enable = lib.mkDefault true;

  # Applications (direct installs — no extra configuration needed)
  environment.systemPackages = with pkgs; [
    google-chrome # Browser
    slack # Communication
    discord # Communication
    teams-for-linux # Communication (Microsoft Teams)
    obsidian # Knowledge management (install Terminal + Web Clipper community plugins)
  ];
}
