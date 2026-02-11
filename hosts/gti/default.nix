{ ... }:

{
  # Dell XPS 13 9370 specific configuration

  imports = [
    ./hardware-configuration.nix
  ];

  # Disko disk device for this machine (NVMe SSD)
  disko.devices.disk.main.device = "/dev/nvme0n1";

  # Machine-specific overrides (Phase 5)
}
