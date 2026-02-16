{ user, ... }:

{
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = "/home/${user}/.config/sops/age/keys.txt";
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

  sops.secrets.atuin_key = {
    owner = user;
    mode = "0400";
  };
}
