{ config, lib, pkgs, ... }:

{
  # Define user account
  users.users.tom = {
    isNormalUser = true;
    description = "Tom";
    extraGroups = [
      "wheel" # sudo
      "networkmanager" # network management
      "video" # video devices
      "audio" # audio devices
      "docker" # docker (if enabled)
    ];

    # Fish as default shell
    shell = pkgs.fish;

    # SSH public keys (if needed for deployment)
    # openssh.authorizedKeys.keys = [ "ssh-ed25519 ..." ];
  };

  # Enable fish system-wide
  programs.fish.enable = true;

  # Enable sudo without password for wheel group (optional - remove for production)
  security.sudo.wheelNeedsPassword = lib.mkDefault true;
}
