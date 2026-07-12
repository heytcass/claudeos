{ ... }:

{
  # Dell XPS 13 9370 specific configuration

  imports = [
    ./hardware-configuration.nix
  ];

  # Disko disk device for this machine (NVMe SSD)
  disko.devices.disk.main.device = "/dev/nvme0n1";

  # GNOME stays the default here until the planned reinstall — this host has
  # never run the Hyprland stack and the rip-out plan graduates it last
  # (docs/plans/2026-07-11-gnome-ripout-plan.md, Phase 1: "gti follows at
  # reinstall"). transporter is the inverted host.
  claude-os.gnome.enable = true;

  # Machine-specific overrides (Phase 5)
}
