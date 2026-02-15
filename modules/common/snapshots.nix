# modules/common/snapshots.nix — Snapper btrfs snapshot management.
# Provides: timeline snapshots (hourly safety net) + pre/post rebuild pairs.
{ user, pkgs, ... }:

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
      root = {
        SUBVOLUME = "/";
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_HOURLY = 10;
        TIMELINE_LIMIT_DAILY = 7;
        TIMELINE_LIMIT_WEEKLY = 2;
        TIMELINE_LIMIT_MONTHLY = 0;
        TIMELINE_LIMIT_YEARLY = 0;
      };

      home = {
        SUBVOLUME = "/home";
        ALLOW_USERS = [ user ];
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_HOURLY = 10;
        TIMELINE_LIMIT_DAILY = 7;
        TIMELINE_LIMIT_WEEKLY = 2;
        TIMELINE_LIMIT_MONTHLY = 0;
        TIMELINE_LIMIT_YEARLY = 0;
      };
    };
  };
}
