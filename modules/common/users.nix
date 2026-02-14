{
  lib,
  pkgs,
  user,
  ...
}:

{
  # Define user account
  users.users.${user} = {
    isNormalUser = true;
    description = "Tom";
    extraGroups = [
      "wheel" # sudo
      "networkmanager" # network management
      "video" # video devices
      "audio" # audio devices
    ];

    # Fish as default shell
    shell = pkgs.fish;

    # SSH public keys for passwordless login
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFqJcKOf70muwJzsxYzNf988D7uJty0rtS7cCquQWBsl tom@ubuntu-dev"
    ];
  };

  # Enable fish system-wide
  programs.fish.enable = true;

  # Enable sudo without password for wheel group (optional - remove for production)
  security.sudo.wheelNeedsPassword = lib.mkDefault true;
}
