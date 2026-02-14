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
  options.claude-os.jasper.enable = lib.mkEnableOption "Jasper AI companion daemon and COSMIC applet";

  config = lib.mkIf config.claude-os.jasper.enable {
    # Install daemon and COSMIC applet system-wide
    environment.systemPackages = [
      jasperPkgs.daemon
      jasperPkgs.cosmic-applet
    ];

    # D-Bus service for socket activation
    services.dbus.packages = [
      (pkgs.writeTextFile {
        name = "jasper-dbus-service";
        text = ''
          [D-BUS Service]
          Name=org.jasper.Daemon
          Exec=${jasperPkgs.daemon}/bin/jasper-companion-daemon start
        '';
        destination = "/share/dbus-1/services/org.jasper.Daemon.service";
      })
    ];

    # User systemd service — auto-starts after graphical session
    systemd.user.services.jasper-companion = {
      description = "Jasper AI Companion Daemon";
      after = [ "graphical-session.target" ];
      wants = [ "graphical-session.target" ];
      wantedBy = [ "default.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.writeShellScript "jasper-start" ''
          export ANTHROPIC_API_KEY=$(cat ${config.sops.secrets.jasper_anthropic_api_key.path})
          exec ${jasperPkgs.daemon}/bin/jasper-companion-daemon start
        ''}";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

  }; # end config
}
