# modules/desktop/gnome.nix — GNOME on Wayland.
# Chosen 2026-06 over Niri: familiar, best app integration (portals, file
# pickers, drag-and-drop, Chrome extension native messaging all first-class).
# Compositor experiments (Hyprland, etc.) can return later as specialisations.
{ lib, pkgs, ... }:

let
  hideDesktopEntries = import ../../lib/hideDesktopEntries.nix { inherit pkgs lib; };
in
{
  # GDM + GNOME (Wayland by default)
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Trim the default GNOME app set — we have our own picks for these roles
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    epiphany # browser → Chrome
    geary # mail → web
    gnome-music # music → web/Spotify
    totem # video player
    gnome-console # terminal → Ghostty (home/ghostty.nix)
  ];

  # Disable X11 forwarding over SSH for security
  services.openssh.settings.X11Forwarding = lib.mkDefault false;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Electron apps use native Wayland
  };

  environment.systemPackages = with pkgs; [
    gnome-tweaks

    # Python extension loader for Nautilus. Ghostty bundles its own
    # "Open in Ghostty" context-menu extension (share/nautilus-python/
    # extensions/ghostty.py); this loader is all Nautilus needs to run it.
    # Replaces the built-in "Open in Console" that died with gnome-console.
    nautilus-python

    # Shell extensions (appindicator, caffeine) are installed and enabled
    # per-user via programs.gnome-shell in home/gnome.nix.

    wl-clipboard # Clipboard access (wl-copy / wl-paste)
    zenity # Dialog prompts (claude-ask-desktop)
    gnome-screenshot # CLI capture (claude-screenshot scripts)

    # Provide tab-new-symbolic for Ghostty's libadwaita tab bar.
    # This icon was removed from adwaita-icon-theme in GNOME 46+ and no
    # packaged theme includes it. We drop a minimal SVG into hicolor
    # (the universal fallback theme) so GTK can find it.
    (pkgs.runCommand "hicolor-tab-new-symbolic" { } ''
            mkdir -p $out/share/icons/hicolor/scalable/actions
            cat > $out/share/icons/hicolor/scalable/actions/tab-new-symbolic.svg <<'SVG'
      <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">
        <rect x="7.25" y="3" width="1.5" height="10" rx=".75" fill="#222222"/>
        <rect x="3" y="7.25" width="10" height="1.5" rx=".75" fill="#222222"/>
      </svg>
      SVG
    '')

    # folder-development (~/Projects icon) lives in the ClaudeOS icon theme
    # (modules/desktop/theme.nix) so it's recolored from the same palette as
    # every other folder instead of hardcoding its own grays.

    # Hide unwanted .desktop entries from the launcher
    (hideDesktopEntries [
      "com.google.Chrome"
      "vim"
      "gvim"
      "htop"
      "btop"
      "org.pwmt.zathura"
      "org.pwmt.zathura-cb"
      "org.pwmt.zathura-djvu"
      "org.pwmt.zathura-pdf-mupdf"
      "org.pwmt.zathura-ps"
      "micro"
      "xterm"
      "uxterm"
      "nixos-manual"
      "nm-applet"
      "nm-connection-editor"
      "org.freedesktop.Xwayland"
    ])
  ];
}
