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
  options.claude-os.hyprland.enable = lib.mkEnableOption "the Hyprland compositor (transporter testbed specialisation)";

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
      # Route interfaces explicitly. Without this, nothing serves
      # org.freedesktop.portal.Settings under XDG_CURRENT_DESKTOP=Hyprland: the
      # hyprland portal only implements Screenshot/ScreenCast/GlobalShortcuts,
      # and gtk/gnome are UseIn=gnome — so Settings (how apps read the
      # dark/light color-scheme) answers "no such interface". Fall back to gtk
      # for everything the hyprland portal doesn't implement (Settings,
      # FileChooser, Notification, …).
      config.common.default = [
        "hyprland"
        "gtk"
      ];
    };

    environment.sessionVariables.XDG_CURRENT_DESKTOP = "Hyprland";

    # Secret Service (org.freedesktop.secrets) for the Hyprland session.
    # gdm-password login does NOT run pam_gnome_keyring by default, so the login
    # keyring is never unlocked at login. GNOME's gnome-session papers over this
    # by starting + unlocking the daemon itself; a bare Hyprland session can't,
    # leaving libsecret clients (notably Claude Desktop's OAuth token store)
    # facing a *locked* keyring — which is why Desktop auth fails under Hyprland.
    # Unlock it at login instead, the standard way. Gated to the specialisation,
    # so the default GNOME generation's PAM stack is byte-identical.
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.gdm-password.enableGnomeKeyring = true;

    # Polkit authentication agent — soteria (Rust + GTK4). Replaces the
    # unmaintained polkit-gnome; the NixOS module installs and autostarts the
    # agent (systemd user service), so GUI privilege prompts work. GTK4 means it
    # inherits Stylix's GTK theming rather than needing its own.
    security.soteria.enable = true;
    # ...but don't let its systemd --user service autostart. It runs at
    # graphical-session.target, before UWSM exports XDG_SESSION_ID to the user
    # manager, so it dies ("Could not get XDG session id") and start-limit-hits,
    # leaving a FAILED unit. home/hyprland.nix launches soteria from Hyprland's
    # exec-once instead (inherits the live session env). The unit stays defined
    # (so `systemctl --user start polkit-soteria` still works) but idle.
    systemd.user.services.polkit-soteria.wantedBy = lib.mkForce [ ];

    # CLIs the Quickshell bar and keybinds shell out to. GNOME's settings-daemon
    # handled media/brightness keys and screenshots for free; a bare Hyprland
    # session needs the tools on PATH so the binds in home/hyprland.nix work.
    environment.systemPackages = with pkgs; [
      wl-clipboard # copy/paste (wl-copy / wl-paste)
      grim # screenshots (session-aware capture in modules/common/system.nix)
      slurp # region select for grim
      brightnessctl # XF86MonBrightness keys
      playerctl # XF86Audio play/pause/next/prev keys
      wireplumber # wpctl — volume/mute keys (audio.nix's stated control tool)
    ];

    # Leaner-closure follow-up — drops GNOME from THIS generation (gnome.nix
    # hard-enables it, so force it off here). Trade-off: loses GNOME as an
    # in-session fallback; the reboot-into-default-entry fallback still stands.
    # services.desktopManager.gnome.enable = lib.mkForce false;
  };
}
