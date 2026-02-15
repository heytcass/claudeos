{ lib, pkgs, ... }:

{
  imports = [
    ./terminals.nix
    ./claude.nix
    ./jasper.nix
    ./mcp-system-health
  ];

  # Enable Claude and Jasper by default (override per-host with `false`)
  claude-os.claude.enable = lib.mkDefault true;
  claude-os.jasper.enable = lib.mkDefault true;

  # Applications (direct installs — no extra configuration needed)
  environment.systemPackages = with pkgs; [
    google-chrome # Browser
    slack # Communication
    discord # Communication
    obsidian # Knowledge management (install Terminal + Web Clipper community plugins)
  ];
}
