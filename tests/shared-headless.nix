# Stand-in for a headless consumer of modules/shared — the shape of a server,
# with none of claudeos's desktop stack and no specialArgs. If a shared module
# reaches for home-manager, Stylix, `user`/`inputs`, or a desktop-only option,
# this fails to evaluate. Built in CI (validate.yml, host-build).
{ lib, ... }:
{
  nixpkgs.hostPlatform = "x86_64-linux";

  boot.loader.grub.devices = [ "nodev" ];
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  networking = {
    hostName = "shared-headless";
    useNetworkd = true;
    firewall.enable = true;
  };
  users.mutableUsers = false;
  # No login exists until the shared user module lands (plan step 4), which
  # must delete this line — the stand-in then proves a usable login.
  users.allowNoPasswordLogin = true;
  hardware.enableRedistributableFirmware = lib.mkForce false;

  system.stateVersion = "26.11";
}
