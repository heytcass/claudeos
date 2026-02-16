{ ... }:

{
  # Desktop environment — system-level configuration
  imports = [
    ./niri-system.nix
    ./audio.nix
    ./fonts.nix
    ./theme.nix
  ];
}
