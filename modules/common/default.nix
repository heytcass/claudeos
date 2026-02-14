{ ... }:

{
  imports = [
    ./boot.nix
    ./disko.nix
    ./nix.nix
    ./users.nix
    ./networking.nix
    ./locale.nix
    ./system.nix
    ./secrets.nix
  ];
}
