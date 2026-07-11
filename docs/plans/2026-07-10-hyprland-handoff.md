# Hyprland + Quickshell — handoff to a local session

*2026-07-10. Written by the remote (web) session that built this, for the local
Claude Code session picking it up. The remote loop (rebuild → reboot → paste)
made debugging brutal; a local session can run `qs`, read logs, and hot-reload
directly, so it should close these out fast. Branch:
`claude/wm-evaluation-report-4a6w5t` (PR #38).*

## Opening prompt (paste this to start the local session)

> Read `docs/PHILOSOPHY.md`, `docs/plans/2026-07-10-wm-evaluation-report.md`, and
> this file (`docs/plans/2026-07-10-hyprland-handoff.md`) first. We're mid-build
> on a Hyprland compositor + bespoke Quickshell bar, delivered as a boot-menu
> **specialisation on `transporter` only** (GNOME stays default; `gti`
> untouched). The compositor boots and Colemak/cursor work, but three things are
> broken: (1) the Quickshell bar doesn't load, (2) the gnome-keyring Secret
> Service isn't reaching the session, (3) Ghostty renders black-on-black in the
> Hyprland session. You're local, so **use the fast-reload loop** (below) to fix
> the bar in seconds instead of rebuilding. Start by reproducing bug #1: boot the
> hyprland specialisation (or just run `qs` in it) and read the error.

## Where we are

- **Works** on the `transporter` hyprland specialisation: boots, GDM lists the
  Hyprland (UWSM) session, Colemak keyboard, Adwaita cursor, portals installed,
  soteria polkit agent, companions (fuzzel/hyprlock/hypridle/hyprpaper) present.
- **Broken (the three to fix):**
  1. **Bar doesn't load.** Two load-blocking QML errors were already fixed
     (missing `import QtQuick` for `ListModel`; `QtQuick.Controls` removed since
     nixpkgs quickshell doesn't ship it). The bar *still* didn't appear on the
     last boot, so there is almost certainly a **third** load error we never
     captured. Get it: in the Hyprland session run `qs 2>&1 | head -40` (or read
     the newest `*.qslog` under `$XDG_RUNTIME_DIR/quickshell/by-id/*/`). Because
     Quickshell registers the whole config dir as one module, **any** single
     broken file makes every component "unavailable" and the whole bar vanishes —
     so it's always one file/line; the error chain names it.
  2. **Keyring.** `gnome-keyring-daemon --daemonize --login` IS running (PAM
     started it), but the Secret Service (`org.freedesktop.secrets`) isn't
     exposed/unlocked in the session, so Claude/libsecret can't save logins. The
     `exec-once "gnome-keyring-daemon --start --components=secrets,ssh,pkcs11"`
     in `home/hyprland.nix` isn't sufficient — likely the session isn't
     inheriting `GNOME_KEYRING_CONTROL` from the PAM login instance, so `--start`
     spawns a disconnected daemon. Check `busctl --user list | grep secret` and
     whether the login keyring is unlocked. Likely fix: proper PAM
     (`security.pam.services.<gdm-password|login>.enableGnomeKeyring`) and/or
     starting the secrets component so it attaches to the login daemon.
  3. **Ghostty black-on-black.** Config is `theme = stylix` (a single fixed
     theme; identical file works in GNOME), so it's a **session-level appearance
     override**, not the config. Most likely: no XDG *Settings* portal is
     reporting the dark color-scheme under Hyprland (only
     `xdg-desktop-portal-gtk` is wired, no explicit `xdg.portal.config` routing
     Settings), so libadwaita/Ghostty misresolves colors. Check
     `cat ~/.config/ghostty/themes/stylix`, and whether `org.freedesktop.appearance`
     answers in-session. Fixes to try: route the Settings portal
     (`xdg.portal.config`), ensure `color-scheme=prefer-dark` is visible to the
     portal, or a Ghostty-level override.

## Fast-reload loop (use this — no rebuild per QML fix)

The config is a read-only store symlink, but you can copy it and point `qs` at
the copy, editing freely:
```bash
cp -rL ~/.config/quickshell /tmp/qs        # includes the generated Theme.qml
qs -p /tmp/qs/shell.qml 2>&1 | head -40     # edit /tmp/qs/*.qml, rerun instantly
```
Iterate in `/tmp/qs` until the bar is solid, then port the final `.qml` back into
`home/quickshell/` in the repo and rebuild once to bake it in. Quickshell also
hot-reloads on save, so `qs -p /tmp/qs/shell.qml` left running picks up edits.

## Build / test / caveats

- Files: system module `modules/desktop/hyprland.nix` (gated
  `claude-os.hyprland.enable`, default off); host opt-in in
  `hosts/transporter/default.nix` (`specialisation.hyprland` — the ONLY place
  it's on, and where `home/hyprland.nix` is attached); the shell QML lives in
  `home/quickshell/`.
- `Theme.qml` is **generated** by `home/hyprland.nix` (a `runCommand`) from the
  Stylix base16 palette + `lib/theme.nix` fonts — it is NOT a static file. Icons
  are in `Icons.qml` via `String.fromCharCode(0x…)` (plain-ASCII source; literal
  Nerd-Font glyphs and `\u` escapes both got mangled through the remote tools —
  a local session can use literal glyphs if preferred).
- Validate without switching: `nix build .#nixosConfigurations.transporter.config.system.build.toplevel`,
  `nix flake check`, `nix fmt`. Commit gate denies `.nix` commits unless the
  flake evaluates.
- To run the session: `nixos-rebuild switch` then **reboot into the
  `… (hyprland)` boot entry** — do NOT `switch-to-configuration` into the
  specialisation (HM-in-specialisation live activation is unverified; boot-into
  is the safe path). For QML-only work, use the fast loop above (no reboot).

## Quickshell API gotchas (verified against source @ 2026-07-10, v0.3.x)

Save the local session rediscovery:
- **`PopupWindow` + `PanelWindow` are in `Quickshell` core**, not
  `Quickshell.Wayland`. Popups anchor via `anchor.item` + `anchor.edges` /
  `anchor.gravity` (+ `grabFocus: true` for click-away). Opposing edges are
  illegal.
- **No `QtQuick.Controls`** in the nixpkgs quickshell QML path (only
  `qtdeclarative`). Don't use `MonthGrid`/`ToolTip`/Controls types (we hand-rolled
  the calendar, and made the battery detail a `PopupWindow`). All
  `Quickshell.Services.*` we use (Pipewire, Mpris, UPower, Notifications,
  SystemTray, Hyprland), plus `Quickshell.Io` and `Quickshell.Widgets`, and
  `qtsvg`, ARE available (their `with*` build flags default true).
- **Volume:** `Pipewire.defaultAudioSink.audio.{volume,muted}` are invalid/
  non-writable unless the node is bound with `PwObjectTracker { objects: [...] }`.
  `defaultAudioSink` is briefly null on default change — null-guard. Clamp volume
  to 0..1 (PW allows >1).
- **MPRIS:** `position` is non-reactive — drive a seek bar by emitting
  `player.positionChanged()` from a `FrameAnimation`/`Timer`. Use `trackArtist`
  (singular; `trackArtists` deprecated), `trackArtUrl` (may be http or file).
- **Notifications:** set `notif.tracked = true` in `onNotification` or the
  notification is freed immediately. Capability flags (`actionsSupported`,
  `imageSupported`, …) default **false** — opt in. Only one process may own the
  bus, so **mako is retired** (`services.mako.enable` removed). `Notification.image`
  is a ready `Image.source`; app icons resolve via `Quickshell.iconPath(name)`.
- **Singletons** (`Theme`, `Icons`, `Notifications`): `pragma Singleton` + root
  element `Singleton`, auto-register in the dir, referenced unqualified. One
  broken file breaks the whole dir's type registration (why a single error blanks
  the bar).
- Active window: `Hyprland.activeToplevel?.title`. Battery:
  `UPower.displayDevice.{percentage (0..100), timeToEmpty/timeToFull (seconds),
  state}`.

## Decisions locked (do not relitigate — see the eval report for the why)

- **Hyprland** (over Niri/Mango): fixes GNOME's felt sluggishness; best NixOS
  integration; closes the March-2026 Niri portal/XWayland wounds.
- **Bespoke Quickshell bar** (over DMS/ashell): "build what I want, adopt no
  one's desktop." **ashell (Rust/iced) is the documented fallback** if Quickshell
  churn or the **Qt closure weight** proves too much — Tom flagged the Qt weight;
  worth measuring (`nix path-info -Sh` on the quickshell closure) and revisiting
  if it offends the leanness values. Not a reason to abandon a working shell.
- **soteria** for polkit (Rust, replaced polkit-gnome). Kept: fuzzel, hyprpaper,
  hyprlock/hypridle (all Stylix-targeted, already the right modern picks;
  wpctl/grim/brightnessctl/playerctl confirmed correct — no swaps).
- Scope: specialisation on `transporter` only; GNOME default everywhere; `gti`
  never touched.

## Bar design (what Tom asked for)

Medium density, Nerd-Font icons, terracotta. Left: workspace pills + active
window title. Center: clock/date → **calendar dropdown with notification
history** (GNOME-style). Right: media (album-art popup, hidden when idle) ·
volume (scroll to adjust) · network (name + wifi signal) · battery (time-
remaining popup) · tray. All present in `home/quickshell/`; the job is getting
them to actually render + tuning the look.
