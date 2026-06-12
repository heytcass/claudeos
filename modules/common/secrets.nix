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

}
