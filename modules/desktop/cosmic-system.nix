{ lib, pkgs, ... }:

{
  # Enable X server (required for compatibility layer)
  services.xserver.enable = true;

  # Exclude xterm (pulled in by X server dependencies)
  services.xserver.excludePackages = with pkgs; [
    xterm
  ];

  # Use COSMIC Greeter (COSMIC's display manager)
  services.displayManager.cosmic-greeter.enable = true;

  # Enable COSMIC Desktop Environment
  services.desktopManager.cosmic.enable = true;

  # Disable X11 forwarding over SSH for security
  services.openssh.settings.X11Forwarding = lib.mkDefault false;

  # Core COSMIC packages and tools
  environment.systemPackages = with pkgs; [
    # COSMIC built-in applications
    cosmic-edit # Text editor
    cosmic-files # File manager

    # Icon themes
    # adwaita-icon-theme provides the base symbolic icons that GTK4/libadwaita
    # apps expect. COSMIC doesn't ship these, unlike GNOME.
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

    # Hide unwanted .desktop entries from COSMIC launcher
    # COSMIC doesn't do cross-path XDG deduplication, so overrides must
    # land in the same path (/run/current-system/sw/share/applications/)
    (lib.hiPrio (pkgs.runCommand "desktop-hide-overrides" { } ''
      mkdir -p $out/share/applications
      for name in \
        com.system76.CosmicTerm \
        vim gvim htop micro \
        xterm uxterm \
        nixos-manual \
        nm-applet nm-connection-editor \
        org.freedesktop.Xwayland \
        xdg-desktop-portal-gtk \
        geoclue-where-am-i
      do
        cat > "$out/share/applications/$name.desktop" <<EOF
      [Desktop Entry]
      NoDisplay=true
      EOF
      done
    ''))
  ];

  # Enable GVfs for virtual filesystems (Trash, network shares, etc.)
  services.gvfs.enable = true;
}
