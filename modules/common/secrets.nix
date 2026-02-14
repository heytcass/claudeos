{ ... }:

{
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = "/home/tom/.config/sops/age/keys.txt";
  };

  sops.secrets.jasper_anthropic_api_key = {
    owner = "tom";
    mode = "0400";
  };

  sops.secrets.atuin_key = {
    owner = "tom";
    mode = "0400";
  };
}
