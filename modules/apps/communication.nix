{ pkgs, ... }:

{
  # Install communication applications
  environment.systemPackages = with pkgs; [
    slack
    discord
  ];

  # Note: Both Slack and Discord are unfree packages
  # allowUnfree is already configured in modules/common/nix.nix

  # Login and configuration must be done manually
  # (cannot be managed declaratively)
}
