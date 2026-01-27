{ ... }:

{
  # Import all shell configuration modules
  imports = [
    ./fish.nix
    ./cli-tools.nix
    ./starship.nix
  ];
}
