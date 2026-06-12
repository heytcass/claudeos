{ ... }:

{
  # Desktop environment — system-level configuration
  imports = [
    ./gnome.nix
    ./audio.nix
    ./fonts.nix
    ./theme.nix
  ];
}
