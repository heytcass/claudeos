{ lib, pkgs, ... }:

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
    ];

    # Fish as default shell
    shell = pkgs.fish;

    # SSH public keys for passwordless login
    # Add your key here, then PasswordAuthentication can stay false:
    #   ssh-keygen -t ed25519 -C "tom@<hostname>"
    #   cat ~/.ssh/id_ed25519.pub
    # openssh.authorizedKeys.keys = [
    #   "ssh-ed25519 AAAA... tom@transporter"
    # ];
  };

  # Enable fish system-wide
  programs.fish.enable = true;

  # Enable sudo without password for wheel group (optional - remove for production)
  security.sudo.wheelNeedsPassword = lib.mkDefault true;
}
