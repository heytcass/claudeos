{ ... }:

{
  # Dell Latitude 7280 — TESTBED host for the ClaudeOS return.
  # Purpose: prove the integration story (Claude desktop app, Chrome extension
  # native messaging, VSCode, file pickers/drag-and-drop, MCP experimentation)
  # on real hardware before gti is reinstalled.
  #
  # First-install checklist (see docs/SECRETS.md for details):
  #   1. After install, derive this host's age key:
  #        nix shell nixpkgs#ssh-to-age -c ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
  #   2. Add it to .sops.yaml as &transporter_host and run
  #        sops updatekeys secrets/secrets.yaml
  #      Until then, sops secrets won't decrypt here (jasper will stay down).

  imports = [
    ./hardware-configuration.nix
  ];

  # Disko disk device for this machine (SATA SSD)
  disko.devices.disk.main.device = "/dev/sda";
}
