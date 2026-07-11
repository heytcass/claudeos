---
paths:
  - "home/quickshell/**/*.qml"
  - "home/hyprland.nix"
---

# Quickshell bar — rules that always apply here

The bespoke Hyprland status bar lives in `home/quickshell/*.qml`, assembled +
themed by `home/hyprland.nix`. When editing it:

- **Stylix base16 only — never hardcode hex.** All colour/font/metric values come
  from the `Theme` singleton, which is *generated* in `home/hyprland.nix` from
  `config.lib.stylix.colors` + `lib/theme.nix`. Reference `Theme.accent`,
  `Theme.base0D`, `Theme.fontMono`, etc. Adding a raw `#rrggbb` is a bug.

- **One broken file blanks the whole bar.** Quickshell registers the config dir
  as a single module, so *any* QML load error makes every component
  "unavailable" and the bar vanishes. The error chain names the file+line —
  always fast-reload and read it before rebuilding (see `/qml-dial-in`).

- **`Theme.qml` and `cava.conf` are generated, not source.** They exist only in
  the *deployed* `~/.config/quickshell`, not in `home/quickshell/`. So a preview
  must start from a copy of the deployed dir with the repo's `*.qml` overlaid —
  which is exactly what `qml-preview` does.

- **The build does not validate QML/hyprland.conf contents** — only Nix eval.
  Validate against the running binary before `rebuild`: `qs -p <copy>` loads
  clean, `hyprctl keyword <field> <value>` returns `ok`, `hyprctl configerrors`
  is empty after `hyprctl reload`. (See CLAUDE.md "Compositor config isn't
  validated by the build".)

- **Deploy needs a reboot, not a switch.** The bar is in the `transporter`
  Hyprland *specialisation*; `nixos-rebuild switch` activates GNOME and strips
  the running Hyprland config. Deploy = `rebuild` → reboot into the `(hyprland)`
  boot entry.

**Quickshell 0.3.x API gotchas** (UPower percentage is 0..1 not 0..100, MPRIS
`trackArtist` singular + non-reactive `position`, Pipewire volume needs
`PwObjectTracker`, `notif.tracked = true` or notifications are freed,
`Quickshell.iconPath(name, true)` for an existence-checked path, SystemTray
needs the `//@ pragma UseQApplication` in `shell.qml`, no `QtQuick.Controls`):
the full verified list is in `docs/plans/2026-07-10-hyprland-handoff.md`
(“Quickshell API gotchas”). Read it before reaching for an unfamiliar type.
