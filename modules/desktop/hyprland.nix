# modules/desktop/hyprland.nix — Hyprland compositor, gated OFF by default.
# Enabled only inside the `hyprland` specialisation on transporter (see
# hosts/transporter/default.nix); GNOME (gnome.nix) stays the default GDM
# session on every host. As of Phase 0 of the GNOME rip-out
# (docs/plans/2026-07-11-gnome-ripout-plan.md) this module is no longer
# strictly additive: it replaces GDM with greetd + regreet inside the
# specialisation, so the greeter itself gets proven before the inversion.
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

    environment.sessionVariables = {
      XDG_CURRENT_DESKTOP = "Hyprland";
      # The greeter must be Colemak — passwords get typed there. greetd builds
      # a clean PAM env for the greeter (env on systemd.services.greetd never
      # reaches cage), but pam_env exports environment.sessionVariables, and
      # wlroots/cage read XKB_DEFAULT_*. Harmless in the user session:
      # Hyprland's own input config overrides these env defaults.
      XKB_DEFAULT_LAYOUT = "us";
      XKB_DEFAULT_VARIANT = "colemak";
    };

    # Login manager: greetd + regreet, replacing GDM (Phase 0 of the GNOME
    # rip-out — see the plan doc for the greetd-vs-SDDM decision). regreet is
    # GTK4 under a cage kiosk; enabling it pulls greetd and sets the
    # default_session command. Sessions are discovered via XDG_DATA_DIRS
    # (pam_env supplies it), so the GNOME session stays pickable as long as
    # it's installed. gnome.nix hard-enables GDM, hence the mkForce.
    # Theming: Stylix has an auto-enabled regreet target that sets the whole
    # greeter from the shared source of truth — wallpaper background, base16
    # GTK CSS, sans font, cursor + icon themes, dark polarity. Setting any of
    # those here just conflicts with it (found the hard way: dry-run 2026-07-11).
    services.displayManager.gdm.enable = lib.mkForce false;
    programs.regreet.enable = true;

    # Secret Service (org.freedesktop.secrets): gnome-keyring stays through
    # the rip-out — apps depend on the freedesktop API, not on GNOME; oo7 is
    # the eventual successor (plan doc, Deferred). Under GDM the login-keyring
    # unlock rode gdm-password's substack of `login`; greetd needs it stated:
    # pam_gnome_keyring on the greetd stack unlocks with the login password.
    # The exec-once gnome-keyring-daemon --start in home/hyprland.nix exposes
    # the components in-session.
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.greetd.enableGnomeKeyring = true;

    # GNOME's settings-daemon made the power button suspend (home/gnome.nix
    # power-button-action); logind owns the button in a bare compositor and
    # defaults to poweroff — keep the suspend behavior. Lid switch already
    # suspends by logind default.
    services.logind.settings.Login.HandlePowerKey = "suspend";

    # Location for the night-light sun schedule (home/hyprland.nix gammastep,
    # geoclue2 provider — the same mechanism GNOME's night-light used). GNOME
    # enables geoclue itself today; explicit so it survives the rip-out. The
    # static appConfig entry authorizes gammastep without needing an agent.
    services.geoclue2 = {
      enable = true;
      appConfig.gammastep = {
        isAllowed = true;
        isSystem = false;
      };
    };

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
