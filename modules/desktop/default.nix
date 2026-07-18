# Desktop environment — system-level configuration shared by every desktop
# (GNOME and Hyprland are option-gated; hosts pick via claude-os.*.enable).
{ lib, pkgs, ... }:

let
  hideDesktopEntries = import ../../lib/hideDesktopEntries.nix { inherit pkgs lib; };
in
{
  imports = [
    ./hyprland.nix # inert unless claude-os.hyprland.enable (default false)
    ./audio.nix
    ./fonts.nix
    ./theme.nix
  ];

  # dconf: the settings backend GTK apps + the gtk portal's Settings iface
  # read (icon theme, color-scheme). GNOME used to pull this in implicitly;
  # standalone GTK apps (Nautilus, Loupe) still need it under Hyprland.
  programs.dconf.enable = true;

  # Disable X11 forwarding over SSH for security
  services.openssh.settings.X11Forwarding = lib.mkDefault false;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Electron apps use native Wayland
  };

  environment.systemPackages = with pkgs; [
    wl-clipboard # Clipboard access (wl-copy / wl-paste)
    zenity # Dialog prompts (claude-ask-desktop)

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

    # Hide unwanted .desktop entries from launchers, desktop-agnostic (GNOME
    # Shell and fuzzel read the same entries). ONLY system-installed packages
    # belong here: hides work by hiPrio collision within one profile, so an
    # override in the system profile CANNOT mask a home-managed package —
    # per-user profiles precede /run/current-system/sw in XDG_DATA_DIRS and
    # win. HM-installed hides (btop, zathura, …) live in home/default.nix.
    # (A Chrome hide lived here historically — as "com.google.Chrome", a
    # wrong ID that never matched google-chrome.desktop, so Chrome was always
    # visible in practice. Tom kept it that way on purpose, 2026-07-11.)
    (hideDesktopEntries [
      "nm-applet" # tray applet entry; the bar/Shell owns network status
      "vim"
      "gvim"
      "htop"
      "micro"
      "xterm"
      "uxterm"
      "nixos-manual"
      "org.freedesktop.Xwayland"
    ])
  ];
}
