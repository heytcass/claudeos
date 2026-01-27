{ ... }:

{
  # Phase 2: Desktop Environment
  imports = [
    ./gnome.nix
    ./audio.nix
    ./fonts.nix
    ./theme.nix
  ];
}
