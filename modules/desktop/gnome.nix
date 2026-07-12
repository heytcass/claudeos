# modules/desktop/gnome.nix — GNOME on Wayland, gated OFF by default.
# Originally chosen 2026-06 over Niri; superseded 2026-07 by Hyprland as the
# daily driver (docs/plans/2026-07-11-gnome-ripout-plan.md). GNOME survives as
# gti's default until its reinstall and as transporter's `gnome` fallback
# specialisation during burn-in; Phase 3 deletes this module entirely.
# The module attaches its own home config (home/gnome.nix) so a generation
# either gets the whole GNOME story or none of it.
{
  lib,
  pkgs,
  config,
  user,
  ...
}:
let
  cfg = config.claude-os.gnome;
  hideDesktopEntries = import ../../lib/hideDesktopEntries.nix { inherit pkgs lib; };
in
{
  options.claude-os.gnome.enable = lib.mkEnableOption "the GNOME desktop (GDM session, legacy default)";

  config = lib.mkIf cfg.enable {
    # GDM + GNOME (Wayland by default)
    services.displayManager.gdm.enable = true;
    services.desktopManager.gnome.enable = true;

    home-manager.users.${user}.imports = [ ../../home/gnome.nix ];

    # Trim the default GNOME app set — we have our own picks for these roles
    environment.gnome.excludePackages = with pkgs; [
      gnome-tour
      epiphany # browser → Chrome
      geary # mail → web
      gnome-music # music → web/Spotify
      totem # video player
      gnome-console # terminal → Ghostty (home/ghostty.nix)
    ];

    environment.systemPackages = with pkgs; [
      gnome-tweaks

      # Python extension loader for Nautilus. Ghostty bundles its own
      # "Open in Ghostty" context-menu extension (share/nautilus-python/
      # extensions/ghostty.py); this loader is all Nautilus needs to run it.
      # Replaces the built-in "Open in Console" that died with gnome-console.
      nautilus-python

      # Shell extensions (appindicator, caffeine) are installed and enabled
      # per-user via programs.gnome-shell in home/gnome.nix.

      gnome-screenshot # CLI capture (claude-screenshot scripts, GNOME session)

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

      # GNOME-only hide: GNOME Settings owns network config, so
      # nm-connection-editor is clutter here. The Hyprland generation
      # deliberately leaves it VISIBLE — it IS network settings there.
      # nm-applet + the desktop-agnostic hides live in default.nix.
      (hideDesktopEntries [
        "nm-connection-editor"
      ])
    ];
  };
}
