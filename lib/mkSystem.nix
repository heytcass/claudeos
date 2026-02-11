{ lib }:

{ hostname
, system
, user
, hardwareModules ? [ ]
, modules ? [ ]
, specialArgs ? { }
}:

lib.nixosSystem {
  inherit system specialArgs;
  modules = [
    {
      networking.hostName = hostname;

      # Integrate home-manager as NixOS module
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.${user} = import ../home;
      home-manager.extraSpecialArgs = specialArgs;
    }

    # Common modules shared by all machines
    ../modules/common
    ../modules/desktop
    ../modules/apps
    ../modules/development
    ../modules/services
  ] ++ hardwareModules ++ modules;
}
