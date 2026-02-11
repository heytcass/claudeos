{ lib }:

{ hostname
, system
, user
, hardwareModules ? [ ]
, modules ? [ ]
, specialArgs ? { }
}:

lib.nixosSystem {
  specialArgs = specialArgs // { inherit user; };
  modules = [
    {
      nixpkgs.hostPlatform = system;
      networking.hostName = hostname;

      # Integrate home-manager as NixOS module
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.${user} = import ../home;
      home-manager.extraSpecialArgs = specialArgs // { inherit user; };
      home-manager.backupFileExtension = "backup"; # Auto-backup conflicting files
    }

    # Common modules shared by all machines
    ../modules/common
    ../modules/desktop
    ../modules/apps
  ] ++ hardwareModules ++ modules;
}
