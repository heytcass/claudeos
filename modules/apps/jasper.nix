{
  lib,
  pkgs,
  inputs,
  config,
  user,
  ...
}:

let
  jasperPkgs = inputs.jasper.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  options.claude-os.jasper.enable = lib.mkEnableOption "Jasper AI companion daemon";

  config = lib.mkIf config.claude-os.jasper.enable {
    # Install daemon system-wide (desktop indicator/widget is a follow-up task)
    environment.systemPackages = [
      jasperPkgs.daemon
    ];

    # User systemd service — auto-starts after graphical session
    # Note: D-Bus activation service intentionally removed — it races with the
    # systemd service and spawns instances without SOPS env vars. The systemd
    # service claims the bus name; desktop clients connect via polling.
    systemd.user.services.jasper-companion = {
      description = "Jasper AI Companion Daemon";
      # DEPENDENCY DIRECTION MATTERS (learned 2026-07-05, transporter reinstall):
      # the old `wants = graphical-session.target` + `wantedBy = default.target`
      # made jasper START in every user manager (including GDM's throwaway
      # gdm-greeter users) and PULL graphical-session.target active before
      # gnome-session-init ran — which then aborted with "A graphical session
      # is already running!", killing the greeter in a loop until GDM gave up
      # (black screen, system alive). A user unit must never activate
      # graphical-session.target; it should be pulled in BY it, and only for
      # the real desktop user.
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      unitConfig.ConditionUser = user;

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
