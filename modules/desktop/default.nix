{ ... }:

{
  # Phase 2: Desktop Environment
  imports = [
    ./cosmic-system.nix
    ./audio.nix
    ./fonts.nix
    ./theme.nix
  ];
}
