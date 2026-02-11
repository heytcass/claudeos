{ ... }:

{
  # Desktop environment — system-level configuration
  imports = [
    ./cosmic-system.nix
    ./audio.nix
    ./fonts.nix
    ./theme.nix
  ];
}
