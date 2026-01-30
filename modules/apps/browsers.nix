{ pkgs, ... }:

{
  # Install Chrome browser
  environment.systemPackages = with pkgs; [
    google-chrome
  ];

  # Note: Chrome is unfree, but allowUnfree is already configured
  # in modules/common/nix.nix

  # Chrome extensions and sync must be configured manually
  # (cannot be managed declaratively)
}
