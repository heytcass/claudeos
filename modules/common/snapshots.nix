# modules/common/snapshots.nix — Snapper btrfs snapshot management.
# Provides: timeline snapshots (hourly safety net) + pre/post rebuild pairs.
{ user, pkgs, ... }:

let
  # Shared snapper policy: hourly timeline safety net, plus pruning for the
  # pre/post pairs created by the `rebuild` fish function — without
  # NUMBER_CLEANUP snapper keeps those forever, pinning deleted data
  commonConfig = {
    TIMELINE_CREATE = true;
    TIMELINE_CLEANUP = true;
    TIMELINE_LIMIT_HOURLY = 10;
    TIMELINE_LIMIT_DAILY = 7;
    TIMELINE_LIMIT_WEEKLY = 2;
    TIMELINE_LIMIT_MONTHLY = 0;
    TIMELINE_LIMIT_YEARLY = 0;
    NUMBER_CLEANUP = true;
    NUMBER_LIMIT = 10;
    NUMBER_MIN_AGE = 1800;
    EMPTY_PRE_POST_CLEANUP = true;
  };
in
{
  # Create .snapshots btrfs subvolumes if they don't exist.
  # The NixOS snapper module creates config files but not the subvolumes themselves.
  system.activationScripts.snapperSubvolumes.text = ''
    for path in /.snapshots /home/.snapshots; do
      if [ ! -e "$path" ]; then
        ${pkgs.btrfs-progs}/bin/btrfs subvolume create "$path"
      fi
    done
  '';

  services.snapper = {
    snapshotInterval = "hourly";
    cleanupInterval = "1d";
    persistentTimer = true;

    configs = {
      root = commonConfig // {
        SUBVOLUME = "/";
      };

      home = commonConfig // {
        SUBVOLUME = "/home";
        ALLOW_USERS = [ user ];
      };
    };
  };
}
