{ ... }:

{
  # Desktop environment — system-level configuration
  imports = [
    ./gnome.nix
    ./hyprland.nix # inert unless claude-os.hyprland.enable (default false)
    ./audio.nix
    ./fonts.nix
    ./theme.nix
  ];
}
