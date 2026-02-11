{ pkgs, ... }:

{
  imports = [
    ./terminals.nix
    ./claude.nix
    ./jasper.nix
  ];

  # Applications (direct installs — no extra configuration needed)
  environment.systemPackages = with pkgs; [
    google-chrome # Browser
    slack # Communication
    discord # Communication
    obsidian # Knowledge management (install Terminal + Web Clipper community plugins)
  ];
}
