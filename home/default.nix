{
  config,
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
    ./claude-code.nix
    ./claudeos-help.nix
    ./zathura.nix
  ];

  # This is required for home-manager
  home.stateVersion = "24.11";

  # Basic home configuration
  home.username = user;
  home.homeDirectory = "/home/${user}";

  # XDG user directories — the standard eight use the module defaults
  # ($HOME/Desktop etc.); only the non-standard PROJECTS dir is ours
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    # Don't export XDG_*_DIR as session variables (the 26.05 default) —
    # everything reads ~/.config/user-dirs.dirs directly
    setSessionVariables = false;
    extraConfig = {
      PROJECTS = "${config.home.homeDirectory}/Projects";
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
    BROWSER = "google-chrome-stable";
  };

  # Claude Code CLI installs to ~/.local/bin — on the PATH for every session
  # context (login shells, systemd user units), not just interactive fish
  home.sessionPath = [ "$HOME/.local/bin" ];

  # Default applications for file types
  # Images — Loupe (GNOME GTK4/Rust viewer; imv was an unmaintained Niri-era
  # leftover that rendered undecorated on Mutter)
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # Web — without these, xdg-open falls back to GNOME's mutable per-user
      # association, which drifts and starts empty on a fresh install
      "text/html" = "google-chrome.desktop";
      "x-scheme-handler/http" = "google-chrome.desktop";
      "x-scheme-handler/https" = "google-chrome.desktop";
      "x-scheme-handler/mailto" = "google-chrome.desktop";

      "application/pdf" = "org.pwmt.zathura.desktop";
      "image/png" = "org.gnome.Loupe.desktop";
      "image/jpeg" = "org.gnome.Loupe.desktop";
      "image/gif" = "org.gnome.Loupe.desktop";
      "image/webp" = "org.gnome.Loupe.desktop";
      "image/svg+xml" = "org.gnome.Loupe.desktop";
      "image/tiff" = "org.gnome.Loupe.desktop";
      "image/bmp" = "org.gnome.Loupe.desktop";

      # Archives — File Roller (GNOME); overrides zathura-cb which claims zip/tar/7z/rar for comic book formats
      "application/zip" = "org.gnome.FileRoller.desktop";
      "application/gzip" = "org.gnome.FileRoller.desktop";
      "application/x-tar" = "org.gnome.FileRoller.desktop";
      "application/x-compressed-tar" = "org.gnome.FileRoller.desktop";
      "application/x-bzip-compressed-tar" = "org.gnome.FileRoller.desktop";
      "application/x-bzip2-compressed-tar" = "org.gnome.FileRoller.desktop";
      "application/x-xz-compressed-tar" = "org.gnome.FileRoller.desktop";
      "application/x-zstd-compressed-tar" = "org.gnome.FileRoller.desktop";
      "application/x-7z-compressed" = "org.gnome.FileRoller.desktop";
      "application/vnd.rar" = "org.gnome.FileRoller.desktop";
      "application/x-lzip-compressed-tar" = "org.gnome.FileRoller.desktop";

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
