{
  lib,
  pkgs,
  inputs,
  config,
  ...
}:

let
  jasperPkgs = inputs.jasper.packages.${pkgs.system};
in
{
  options.claude-os.jasper.enable = lib.mkEnableOption "Jasper AI companion daemon";

  config = lib.mkIf config.claude-os.jasper.enable {
    # Install daemon system-wide (Noctalia bar plugin is a follow-up task)
    environment.systemPackages = [
      jasperPkgs.daemon
    ];

    # User systemd service — auto-starts after graphical session
    # Note: D-Bus activation service intentionally removed — it races with the
    # systemd service and spawns instances without SOPS env vars. The systemd
    # service claims the bus name; desktop clients connect via polling.
    systemd.user.services.jasper-companion = {
      description = "Jasper AI Companion Daemon";
      after = [ "graphical-session.target" ];
      wants = [ "graphical-session.target" ];
      wantedBy = [ "default.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.writeShellScript "jasper-start" ''
          export ANTHROPIC_API_KEY=$(cat ${config.sops.secrets.jasper_anthropic_api_key.path})
          export GOOGLE_CLIENT_ID=$(cat ${config.sops.secrets.jasper_google_client_id.path})
          export GOOGLE_CLIENT_SECRET=$(cat ${config.sops.secrets.jasper_google_client_secret.path})
          export GOOGLE_WEATHER_API_KEY=$(cat ${config.sops.secrets.jasper_google_weather_api_key.path})
          export GOOGLE_ROUTES_API_KEY=$(cat ${config.sops.secrets.jasper_google_routes_api_key.path})
          export HOME_ADDRESS=$(cat ${config.sops.secrets.jasper_home_address.path})
          exec ${jasperPkgs.daemon}/bin/jasper-companion-daemon start
        ''}";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

  }; # end config
}
