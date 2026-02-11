{ lib, ... }:

{
  # Disko configuration for ClaudeOS btrfs layout
  # This defines our standard disk layout with btrfs subvolumes
  #
  # Layout:
  # - 512MB EFI boot partition (vfat)
  # - Remainder as btrfs with subvolumes:
  #   - @ (root)
  #   - @home (user data)
  #   - @nix (nix store)
  #   - @log (logs)
  #
  # Mount options are optimized for SSD with compression
  #
  # NOTE: This module is disabled by default (disko.enableConfig = false)
  # to avoid conflicts with existing hardware-configuration.nix on
  # already-installed systems. Enable it only during installation.

  disko.enableConfig = lib.mkDefault false;

  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = lib.mkDefault "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
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
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ]; # Force overwrite if needed
                subvolumes = {
                  # Root subvolume
                  "@" = {
                    mountpoint = "/";
                    mountOptions = [
                      "noatime"
                      "compress=zstd:3"
                      "ssd"
                      "discard=async"
                      "space_cache=v2"
                    ];
                  };
                  # Home directories
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [
                      "noatime"
                      "compress=zstd:3"
                      "ssd"
                      "discard=async"
                      "space_cache=v2"
                    ];
                  };
                  # Nix store
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "noatime"
                      "compress=zstd:3"
                      "ssd"
                      "discard=async"
                      "space_cache=v2"
                    ];
                  };
                  # Logs
                  "@log" = {
                    mountpoint = "/var/log";
                    mountOptions = [
                      "noatime"
                      "compress=zstd:3"
                      "ssd"
                      "discard=async"
                      "space_cache=v2"
                    ];
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
