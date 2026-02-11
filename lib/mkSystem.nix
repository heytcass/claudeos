{ lib }:

{ hostname
, system
, user
, hardwareModules ? [ ]
, modules ? [ ]
, specialArgs ? { }
}:

lib.nixosSystem {
  inherit system;
  specialArgs = specialArgs // { inherit user; };
  modules = [
    {
      networking.hostName = hostname;

      # Integrate home-manager as NixOS module
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.${user} = import ../home;
      home-manager.extraSpecialArgs = specialArgs // { inherit user; };
    }

    # Common modules shared by all machines
    ../modules/common
    ../modules/desktop
    ../modules/apps
  ] ++ hardwareModules ++ modules;
}
