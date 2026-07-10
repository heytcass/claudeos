# modules/desktop/hyprland.nix — Hyprland compositor, gated OFF by default.
# Enabled only inside the `hyprland` specialisation on transporter (see
# hosts/transporter/default.nix); GNOME (gnome.nix) stays the default GDM
# session on every host. When on, GDM lists a Hyprland (UWSM) session
# alongside GNOME, so the specialisation is strictly additive.
#
# Chosen 2026-07 to answer GNOME's "heavy for what little it shows"
# sluggishness with a lean C compositor (no JS shell). See the evaluation
# report: docs/plans/2026-07-10-wm-evaluation-report.md.
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.claude-os.hyprland;
in
{
  options.claude-os.hyprland.enable =
    lib.mkEnableOption "the Hyprland compositor (transporter testbed specialisation)";

  config = lib.mkIf cfg.enable {
    # Hyprland from nixpkgs (nixos-unstable) — Mesa matches the system by
    # construction, sidestepping the flake-Hyprland GPU-glitch. UWSM is the
    # recommended session launcher; GDM shows hyprland-uwsm.desktop.
    programs.hyprland = {
      enable = true;
      withUWSM = true;
    };

    # xdg-desktop-portal-hyprland (screencast with a picker + global shortcuts)
    # rides in with programs.hyprland. Add the GTK portal for file pickers, so
    # the Hyprland session has file-chooser parity with GNOME's.
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };

    environment.sessionVariables.XDG_CURRENT_DESKTOP = "Hyprland";

    # CLIs the Quickshell bar and keybinds shell out to (screenshots, clipboard).
    environment.systemPackages = with pkgs; [
      wl-clipboard
      grim
      slurp
    ];

    # Leaner-closure follow-up — drops GNOME from THIS generation (gnome.nix
    # hard-enables it, so force it off here). Trade-off: loses GNOME as an
    # in-session fallback; the reboot-into-default-entry fallback still stands.
    # services.desktopManager.gnome.enable = lib.mkForce false;
  };
}
