{ user, ... }:

{
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    # Decryption uses the SSH host key automatically (sops.age.sshKeyPaths),
    # which is available during early boot — unlike a user home directory key.
  };

  sops.secrets.jasper_anthropic_api_key = {
    owner = user;
    mode = "0400";
  };

  sops.secrets.jasper_google_client_id = {
    owner = user;
    mode = "0400";
  };

  sops.secrets.jasper_google_client_secret = {
    owner = user;
    mode = "0400";
  };

  sops.secrets.jasper_google_weather_api_key = {
    owner = user;
    mode = "0400";
  };

  sops.secrets.jasper_google_routes_api_key = {
    owner = user;
    mode = "0400";
  };

  sops.secrets.jasper_home_address = {
    owner = user;
    mode = "0400";
  };

  # UniFi MCP server credential — fish exports UNIFI_API_KEY from this path;
  # .mcp.json expands it from the environment (never hardcoded in git again)
  sops.secrets.unifi_api_key = {
    owner = user;
    mode = "0400";
  };

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
