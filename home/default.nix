{
  pkgs,
  lib,
  user,
  ...
}:

let
  hideDesktopEntries = import ../lib/hideDesktopEntries.nix { inherit pkgs lib; };
in
{
  # Import all Home Manager modules
  imports = [
    ./shell
    ./ghostty.nix
    ./git.nix
    ./vscode.nix
    ./cosmic.nix
    ./cosmic-theme.nix
    ./macchina.nix
    ./claude-code.nix
  ];

  # This is required for home-manager
  home.stateVersion = "24.11";

  # Basic home configuration
  home.username = user;
  home.homeDirectory = "/home/${user}";

  # XDG user directories
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    desktop = "/home/${user}/Desktop";
    documents = "/home/${user}/Documents";
    download = "/home/${user}/Downloads";
    music = "/home/${user}/Music";
    pictures = "/home/${user}/Pictures";
    publicShare = "/home/${user}/Public";
    templates = "/home/${user}/Templates";
    videos = "/home/${user}/Videos";
    extraConfig = {
      PROJECTS = "/home/${user}/Projects";
    };
  };

  # Set development folder icon for ~/Projects
  home.file."Projects/.directory".text = ''
    [Desktop Entry]
    Icon=folder-development
  '';

  # Default editor for all shells and programs (not just interactive Fish)
  home.sessionVariables = {
    EDITOR = "code";
    VISUAL = "code";
  };

  # Let home-manager manage itself
  programs.home-manager.enable = true;

  # Hide unwanted apps from COSMIC launcher (per-user profile entries)
  home.packages = [
    (hideDesktopEntries [
      "yazi"
      "code-url-handler"
      "kvantummanager"
      "qt5ct"
      "qt6ct"
    ])
  ];
}
