{ config, pkgs, ... }:

let
  scheme = config.stylix.base16Scheme;
in
{
  home.packages = [ pkgs.macchina ];

  xdg.configFile."macchina/macchina.toml".text = ''
    theme = "claudeos"

    show = [
      "Host",
      "Distribution",
      "DesktopEnvironment",
      "Shell",
      "Uptime",
      "Memory",
      "Packages",
    ]
  '';

  xdg.configFile."macchina/themes/claudeos.toml".text = ''
    key_color = "#${scheme.base09}"
    separator = " · "
    separator_color = "#${scheme.base03}"
    spacing = 2
    padding = 0

    [custom_ascii]
    color = "#${scheme.base08}"
    path = "${config.home.homeDirectory}/.config/macchina/ascii/clawd.txt"

    [bar]
    glyph = "●"
    symbol_open = '['
    symbol_close = ']'
    hide_delimiters = false
    visible = true

    [box]
    visible = true
    border = "rounded"

    [palette]
    visible = false

    [keys]
    host = "host"
    distribution = "distro"
    desktop_environment = "de"
    shell = "shell"
    uptime = "uptime"
    memory = "memory"
    packages = "pkgs"
  '';

  xdg.configFile."macchina/ascii/clawd.txt".text = ''

     ▐▛███▜▌
    ▝▜█████▛▘
      ▘▘ ▝▝
  '';
}
