{ lib, user, ... }:

{
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    # Decryption uses the SSH host key automatically (sops.age.sshKeyPaths),
    # which is available during early boot — unlike a user home directory key.
  };

  # Every secret is user-owned, mode 0400. The jasper_* six feed the Jasper
  # daemon (modules/apps/jasper.nix); unifi_api_key is exported by fish as
  # UNIFI_API_KEY for the UniFi MCP server (.mcp.json expands it from the
  # environment — never hardcoded in git again).
  sops.secrets =
    lib.genAttrs
      [
        "jasper_anthropic_api_key"
        "jasper_google_client_id"
        "jasper_google_client_secret"
        "jasper_google_weather_api_key"
        "jasper_google_routes_api_key"
        "jasper_home_address"
        "unifi_api_key"
      ]
      (_: {
        owner = user;
        mode = "0400";
      });

  # PENDING (uncomment once the key exists in secrets/secrets.yaml):
  # GitHub fine-grained PAT (this repo only; contents + pull-requests r/w)
  # for the headless automation lane. With lingering, auto-update/self-heal
  # can run with no session — the keyring-backed gh token is locked there,
  # so the preamble's claudeos_export_gh_token exports this as GH_TOKEN.
  # To activate:
  #   1. Mint the PAT at github.com/settings/personal-access-tokens
  #   2. sops set secrets/secrets.yaml '["github_automation_token"]' '"<PAT>"'
  #   3. Uncomment this block and rebuild.
  # sops.secrets.github_automation_token = {
  #   owner = user;
  #   mode = "0400";
  # };

}
