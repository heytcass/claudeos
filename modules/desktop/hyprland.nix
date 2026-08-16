# modules/desktop/hyprland.nix — THE ClaudeOS desktop (GNOME was removed
# entirely in the 2026-07 rip-out; docs/plans/2026-07-11-gnome-ripout-plan.md
# records the decisions). The module attaches its own home config
# (home/hyprland.nix) and owns everything a full DE would otherwise provide —
# login manager (greetd + the Quickshell greeter), keyring PAM, power policy,
# night light,
# and the standalone app set (Files, calculator, image viewer, settings
# surfaces). Still option-gated so a host or specialisation can turn it off.
#
# Chosen 2026-07 to answer GNOME's "heavy for what little it shows"
# sluggishness with a lean C compositor (no JS shell). See the evaluation
# report: docs/plans/2026-07-10-wm-evaluation-report.md.
{
  lib,
  pkgs,
  config,
  user,
  ...
}:
let
  cfg = config.claude-os.hyprland;
in
{
  options.claude-os.hyprland.enable = lib.mkEnableOption "the Hyprland desktop (compositor + bespoke Quickshell bar)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.imports = [ ../../home/hyprland.nix ];
    # Hyprland from nixpkgs (nixos-unstable) — Mesa matches the system by
    # construction, sidestepping the flake-Hyprland GPU-glitch. UWSM is the
    # session launcher — the greeter launches hyprland-uwsm.desktop's argv
    # directly (built from config.programs.uwsm.package in greeter.nix) rather
    # than discovering session files at runtime.
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

    # Login manager: greetd + the bespoke Quickshell greeter
    # (modules/desktop/greeter.nix). greetd and cage were kept from the rip-out
    # choice; only the process inside the kiosk changed, from regreet (GTK4) to
    # quickshell — see docs/plans/2026-08-15-quickshell-greeter-plan.md.
    #
    # mkDefault, not a bare `true`: a host may still turn the greeter off, but
    # a host that enables this desktop and says nothing must not end up with NO
    # login manager. That is the trap that made deleting the old
    # `services.displayManager.regreet.enable = true` line insufficient on its
    # own — the declaration was load-bearing even though regreet was not.
    #
    # The old regreet-era warning about the session picker is now enforced
    # rather than documented: the greeter offers ONLY the "Hyprland (UWSM)"
    # entry, because the plain one never activates graphical-session.target and
    # strands hyprpaper/hypridle/gammastep.
    claude-os.greeter.enable = lib.mkDefault true;

    # Secret Service (org.freedesktop.secrets): gnome-keyring stays through
    # the rip-out — apps depend on the freedesktop API, not on GNOME; oo7 is
    # the eventual successor (plan doc, Deferred). Under GDM the login-keyring
    # unlock rode gdm-password's substack of `login`; greetd needs it stated:
    # pam_gnome_keyring on the greetd stack unlocks with the login password.
    # The exec-once gnome-keyring-daemon --start in home/hyprland.nix exposes
    # the components in-session.
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.greetd.enableGnomeKeyring = true;
    # hyprlock needs its own PAM stack. Without this it logs on every launch:
    #   ERR ]: Pam module "/etc/pam.d/hyprlock" does not exist!
    #          Falling back to "/etc/pam.d/su"
    # Authentication still succeeds through the `su` fallback (it did on every
    # unlock in the journal), so this never blocked a login — but the su stack
    # carries no pam_gnome_keyring, so unlocking the screen does not unlock the
    # keyring the way unlocking at the greeter does. Found 2026-08-15 while
    # diagnosing the lockscreen wedge; not a contributing cause of it.
    security.pam.services.hyprlock.enableGnomeKeyring = true;

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

    # Polkit authentication agent: the BAR is the agent (PolkitDialog.qml,
    # Quickshell.Services.Polkit). soteria is gone, and so is the workaround it
    # needed — which is the actual reason for the swap, not the theming.
    #
    # soteria's systemd --user service starts at graphical-session.target,
    # BEFORE UWSM exports XDG_SESSION_ID to the user manager, so it died with
    # "Could not get XDG session id" and start-limit-hit, leaving a FAILED unit.
    # The fix was to disable that unit and launch soteria from Hyprland's
    # exec-once so it inherited the live session env. Two moving parts to
    # maintain an ordering guarantee.
    #
    # Running the agent inside the already-running bar makes the ordering
    # question disappear: by the time the bar exists, the session variables are
    # exported. No second process, no disabled unit, no exec-once entry.
    #
    # Recovery if the bar is ever dead when a prompt is needed: `systemctl
    # --user start polkit-gnome-authentication-agent-1` is NOT available here;
    # run the privileged action from a TTY with sudo instead. This is the same
    # exposure as before — soteria also died with the bar's session.

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

      # The standalone app set (rip-out decisions: keep the good GNOME apps,
      # they run fine without GNOME and stay Stylix/libadwaita-themed).
      nautilus # Files — inode/directory handler in home/default.nix mimeApps
      nautilus-python # loader for Ghostty's "Open in Ghostty" context menu
      gnome-calculator
      loupe # image viewer — image/* handler in mimeApps
      file-roller # archives — application/zip etc. in mimeApps
      mpv # video (Showtime/Totem never made the cut)

      # Per-domain "Settings" surfaces (windowrules in home/hyprland.nix
      # already float these): audio, bluetooth, network, displays. The shared
      # hide list deliberately does NOT hide nm-connection-editor here — under
      # GNOME it was clutter next to Settings; here it IS network settings.
      pavucontrol
      networkmanagerapplet # nm-connection-editor (visible); nm-applet entry stays hidden
      nwg-displays # monitor layout GUI, writes Hyprland monitor config
    ];

    # Nautilus outside GNOME: gvfs for trash/MTP/network mounts, and the two
    # lines GNOME's module normally provides so Nautilus finds python
    # extensions (Ghostty's context-menu entry rides on nautilus-python).
    services.gvfs.enable = true;
    environment.pathsToLink = [ "/share/nautilus-python/extensions" ];
    environment.sessionVariables.NAUTILUS_4_EXTENSION_DIR = "${config.system.path}/lib/nautilus/extensions-4";

    # Bluetooth manager (GUI + tray applet). blueman-applet is D-Bus activated
    # on demand; blueman-manager is the settings surface.
    services.blueman.enable = true;

  };
}
