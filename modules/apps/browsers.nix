{ pkgs, ... }:

{
  # Google Chrome (unfree, allowed via modules/common/nix.nix)
  environment.systemPackages = [ pkgs.google-chrome ];

  # Chrome extensions and sync must be configured manually
}
