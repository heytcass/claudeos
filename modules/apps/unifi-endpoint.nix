_:

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
  programs.unifi-endpoint.enable = true;
}
