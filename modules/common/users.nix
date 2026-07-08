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
      "dialout" # serial devices
      "kvm" # auto-update VM smoke-test gate boots QEMU from a user unit
    ];

    # Fish as default shell
    shell = pkgs.fish;

    # Keep the user manager (and every claudeos-* user timer) running with no
    # login session — the overnight automation lane must not depend on being
    # logged in ("absence is the resource", PHILOSOPHY.md). Suspend still
    # pauses timers; Persistent=true catches those up at wake.
    linger = true;

    # SSH public keys for passwordless login
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFqJcKOf70muwJzsxYzNf988D7uJty0rtS7cCquQWBsl tom@ubuntu-dev"
      # gti (Ubuntu era) — used to drive transporter installs/admin remotely
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGUt1Q2bElRhISBmkOz3iR4wkW4I7yFFTd3x0qLQTBhb gti-claudeos-install"
    ];
  };

  # Enable fish system-wide
  programs.fish.enable = true;

  # sudo-rs: memory-safe Rust sudo (what Ubuntu ships by default now).
  # Same wheel semantics; the original sudo is disabled in its favor.
  security.sudo.enable = false;
  security.sudo-rs = {
    enable = true;
    wheelNeedsPassword = lib.mkDefault true;
  };
}
