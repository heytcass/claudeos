{ lib, pkgs, ... }:

let
  hideDesktopEntries = import ../../lib/hideDesktopEntries.nix { inherit pkgs lib; };
in
{
  # Enable Niri compositor (niri-flake handles the package and session registration)
  programs.niri.enable = true;

  # Disable niri-flake's bundled KDE polkit agent — it crashes on every boot before
  # the Wayland session is ready (boot race), then self-heals via Restart=on-failure.
  # Noctalia's native polkit-agent plugin handles auth prompts instead (runs inside
  # Quickshell, so no race condition possible).
  systemd.user.services.niri-flake-polkit.enable = lib.mkForce false;

  # greetd + tuigreet — minimal TUI greeter
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --cmd niri-session";
        user = "greeter";
      };
    };
  };

  # Disable X11 forwarding over SSH for security
  services.openssh.settings.X11Forwarding = lib.mkDefault false;

  # Wayland session environment variables
  environment.sessionVariables = {
    GDK_BACKEND = "wayland,x11"; # GTK: prefer Wayland, fall back to X11
    QT_QPA_PLATFORM = "wayland;xcb"; # Qt: prefer Wayland, fall back to XCB
    NIXOS_OZONE_WL = "1"; # Electron apps use native Wayland
  };

  # Core packages for the Niri desktop
  environment.systemPackages = with pkgs; [
    # Wayland utilities
    wl-clipboard # Clipboard access (wl-copy / wl-paste)
    cliphist # Clipboard history manager
    fuzzel # Application launcher
    brightnessctl # Backlight control
    grim # Screenshot capture
    slurp # Region selection
    satty # Screenshot annotation
    xarchiver # Lightweight GTK archive manager

    # Icon themes
    # adwaita-icon-theme provides the base symbolic icons that GTK4/libadwaita
    # apps expect — not bundled by Niri or Noctalia
    adwaita-icon-theme

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

    # folder-development icon for ~/Projects (matches COSMIC icon style)
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

    # Hide unwanted .desktop entries from launcher
    (hideDesktopEntries [
      "com.google.Chrome"
      "vim"
      "gvim"
      "htop"
      "micro"
      "xterm"
      "uxterm"
      "nixos-manual"
      "nm-applet"
      "nm-connection-editor"
      "org.freedesktop.Xwayland"
      "xdg-desktop-portal-gtk"
      "geoclue-where-am-i"
    ])
  ];

  # Thunar file manager — the module (not bare packages) wraps Thunar so its
  # plugins (archive handling, removable media) are actually discovered
  programs.thunar = {
    enable = true;
    plugins = with pkgs.xfce; [
      thunar-archive-plugin
      thunar-volman
    ];
  };

  # xfconf persists Thunar preferences between sessions
  programs.xfconf.enable = true;

  # Enable GVfs for virtual filesystems (Trash, network shares, etc.)
  services.gvfs.enable = true;

  # Tumbler — thumbnail service for Thunar (images, videos, PDFs)
  services.tumbler.enable = true;
}
