{ pkgs, lib, ... }:

{
  # UniFi Endpoint — Ubiquiti's UniFi Identity client (VPN, WiFi/802.1X,
  # credentials). Ring 1 despite being a vendor app: the nixpkgs module has to
  # bind-mount the package at /usr/lib/UniFi-Endpoint (the daemon rejects any
  # client whose /proc/<pid>/exe lives elsewhere), install a polkit rule for
  # its pkexec helper and enable a socket-activated user daemon — none of
  # which a self-updating install could do on NixOS anyway.
  #
  # WiFi/802.1X login needs NetworkManager (modules/common/networking.nix).
  # Installing a workspace CA from inside the app fails here (it shells out
  # to update-ca-certificates); add one via security.pki.certificateFiles.
  programs.unifi-endpoint = {
    enable = true;
    # Temporary: nixpkgs bumped to 1.1.7-28 in 25914a154d (2026-10-11) but it
    # went via staging and hasn't reached nixos-unstable yet. The in-app
    # "update available" nag is for this version. Once nixpkgs ships it the
    # assertion fails the build — delete this override then.
    package =
      assert lib.assertMsg (lib.versionOlder pkgs.unifi-endpoint.version "1.1.7-28")
        "nixpkgs now ships unifi-endpoint ${pkgs.unifi-endpoint.version}; drop the override in modules/apps/unifi-endpoint.nix";
      pkgs.unifi-endpoint.overrideAttrs {
        version = "1.1.7-28";
        src = pkgs.fetchurl {
          url = "https://fw-download.ubnt.com/data/unifi-endpoint-desktop-app-deb/55c2-linux-1.1.7-28-54b0e439-ddb5-41be-9e6f-56739775cdd9.deb";
          hash = "sha256-mWzVcMMNw+yVID7vC8he92g7mZrePlXK3D3b7XWuWa0=";
        };
      };
  };
}
