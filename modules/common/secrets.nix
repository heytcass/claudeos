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
  # environment — never hardcoded in git again); github_automation_token is
  # the headless automation lane's fine-grained PAT (exported as GH_TOKEN by
  # claudeos_export_gh_token in lib/claude-script.nix — see docs/SECRETS.md).
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
        "github_automation_token"
      ]
      (_: {
        owner = user;
        mode = "0400";
      });
}
