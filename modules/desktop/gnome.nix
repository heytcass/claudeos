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

  # Nautilus "Open in Terminal" context menu → Ghostty (replaces the
  # built-in "Open in Console" entry that died with gnome-console above)
  programs.nautilus-open-any-terminal = {
    enable = true;
    terminal = "ghostty";
  };

  # Disable X11 forwarding over SSH for security
  services.openssh.settings.X11Forwarding = lib.mkDefault false;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Electron apps use native Wayland
  };

  environment.systemPackages = with pkgs; [
    gnome-tweaks

    # AppIndicator/StatusNotifier host. GNOME ships no system tray, so apps
    # that expose a tray icon (e.g. Claude Desktop) have nowhere to render
    # without this. Enabled per-user via dconf in home/gnome.nix.
    gnomeExtensions.appindicator

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

    # folder-development icon for ~/Projects
    (pkgs.runCommand "hicolor-folder-development" { } ''
      mkdir -p $out/share/icons/hicolor/scalable/places
      cat > $out/share/icons/hicolor/scalable/places/folder-development.svg <<'SVG'
      <svg width="256" height="256" fill="none" viewBox="0 0 256 256" xmlns="http://www.w3.org/2000/svg">
        <path d="m8 56c0-8.8366 7.1634-16 16-16h71.797c3.3814 0 6.6759 1.0713 9.4109 3.0602l13.584 9.8796c2.735 1.9889 6.029 3.0602 9.411 3.0602h103.8c8.837 0 16 7.1634 16 16v128c0 8.837-7.163 16-16 16h-208c-8.8366 0-16-7.163-16-16z" fill="url(#a)"/>
        <path d="m8 88c0-8.8366 7.1634-16 16-16h208c8.837 0 16 7.1634 16 16v112c0 8.837-7.163 16-16 16h-208c-8.8366 0-16-7.163-16-16z" fill="url(#b)"/>
        <g fill="none" stroke="#fff" stroke-width="10" stroke-linecap="round" stroke-linejoin="round">
          <path d="m100 126 -20 24 20 24"/>
          <path d="m156 126 20 24-20 24"/>
          <path d="m140 114-24 72"/>
        </g>
        <defs>
          <linearGradient id="a" x1="121" x2="121" y1="72.5" y2="40" gradientUnits="userSpaceOnUse">
            <stop stop-color="#484848"/>
            <stop stop-color="#636363" offset="1"/>
          </linearGradient>
          <linearGradient id="b" x1="248" x2="40.837" y1="72" y2="253.48" gradientUnits="userSpaceOnUse">
            <stop stop-color="#979FAD"/>
            <stop stop-color="#808080" offset="1"/>
          </linearGradient>
        </defs>
      </svg>
      SVG
      cat > $out/share/icons/hicolor/scalable/places/folder-development-symbolic.svg <<'SVG'
      <svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
        <g clip-path="url(#a)">
          <path d="M0 0h16v16H0z" fill="#808080" fill-opacity="0"/>
          <path d="M2.5 1C1.672 1 1 1.672 1 2.5v5.793c0 .398.158.779.44 1.06l5.353 5.354a1.5 1.5 0 0 0 2.121 0l5.793-5.793a1.5 1.5 0 0 0 0-2.121L9.354 1.44A1.5 1.5 0 0 0 8.293 1H2.5z" fill="#232323"/>
          <g stroke="#fff" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round">
            <path d="m6 5.5-2 2 2 2"/>
            <path d="m10 5.5 2 2-2 2"/>
            <path d="m9 4.5-2 6"/>
          </g>
        </g>
        <defs>
          <clipPath id="a"><rect width="16" height="16" fill="white"/></clipPath>
        </defs>
      </svg>
      SVG
    '')

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
