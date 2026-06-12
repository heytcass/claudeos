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
    ./gnome.nix
    ./macchina.nix
    ./claude-code.nix
    ./claudeos-help.nix
    ./zathura.nix
    ./imv.nix
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

  # Default editor for all shells and programs (not just interactive Fish).
  # --wait makes VSCode block until the file is closed — without it, anything
  # that waits on $EDITOR (git commit, sops, systemctl edit) sees the editor
  # exit instantly and aborts.
  home.sessionVariables = {
    EDITOR = "code --wait";
    VISUAL = "code --wait";
  };

  # Default applications for file types
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "application/pdf" = "org.pwmt.zathura.desktop";
      "image/png" = "imv.desktop";
      "image/jpeg" = "imv.desktop";
      "image/gif" = "imv.desktop";
      "image/webp" = "imv.desktop";
      "image/svg+xml" = "imv.desktop";
      "image/tiff" = "imv.desktop";
      "image/bmp" = "imv.desktop";

      # Archives — override zathura-cb which claims zip/tar/7z/rar for comic book formats
      "application/zip" = "xarchiver.desktop";
      "application/gzip" = "xarchiver.desktop";
      "application/x-tar" = "xarchiver.desktop";
      "application/x-compressed-tar" = "xarchiver.desktop";
      "application/x-bzip-compressed-tar" = "xarchiver.desktop";
      "application/x-bzip2-compressed-tar" = "xarchiver.desktop";
      "application/x-xz-compressed-tar" = "xarchiver.desktop";
      "application/x-zstd-compressed-tar" = "xarchiver.desktop";
      "application/x-7z-compressed" = "xarchiver.desktop";
      "application/vnd.rar" = "xarchiver.desktop";
      "application/x-lzip-compressed-tar" = "xarchiver.desktop";

      # Directories — open in Nautilus (GNOME Files)
      "inode/directory" = "org.gnome.Nautilus.desktop";
    };
  };

  # Let home-manager manage itself
  programs.home-manager.enable = true;

  # Hide unwanted apps from launcher (per-user profile entries)
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
