{ lib, ... }:

let
  btrfsMountOpts = [
    "noatime"
    "compress=zstd:3"
    "ssd"
    "discard=async"
    "space_cache=v2"
  ];
in
{
  # Disko configuration for ClaudeOS btrfs layout
  #
  # Layout:
  # - 1GB EFI boot partition (vfat)
  # - Remainder as btrfs with subvolumes:
  #   - @ (root)
  #   - @home (user data)
  #   - @nix (nix store)
  #   - @log (logs)
  #
  # Mount options are optimized for SSD with compression
  #
  # Disko generates fileSystems and swapDevices entries declaratively.
  # hardware-configuration.nix only needs kernel modules and CPU config.

  disko.enableConfig = lib.mkDefault true;

  disko.devices = {
    disk = {
      main = {
        type = "disk";
        # No default device — each host must pin its own disk (hosts/<name>/default.nix)
        # so a new host fails evaluation instead of silently targeting the wrong drive.
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "fmask=0022"
                  "dmask=0022"
                ];
              };
            };
            # Swap is handled by zram (modules/common/system.nix)
            # No disk-based swap partition — keeps layout simple
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ]; # Force overwrite if needed
                subvolumes = {
                  "@" = {
                    mountpoint = "/";
                    mountOptions = btrfsMountOpts;
                  };
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = btrfsMountOpts;
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = btrfsMountOpts;
                  };
                  "@log" = {
                    mountpoint = "/var/log";
                    mountOptions = btrfsMountOpts;
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
