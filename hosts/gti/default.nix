{ ... }:

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
}
