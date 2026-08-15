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
  Validate against the Hyprland binary before `rebuild`: `qs -p <copy>` loads
  clean, and `Hyprland --verify-config -c <file>` prints `config ok`. Do NOT
  use `hyprctl keyword` — it only works on hyprlang configs (`hyprctl eval`
  only on Lua ones), so it breaks across a format migration. `--verify-config`
  is format-agnostic. Note it needs `XDG_RUNTIME_DIR` set or it aborts with
  exit 134 regardless of whether the config is valid. (See CLAUDE.md
  "Compositor config isn't validated by the build".)

- **Deploy = `rebuild`, then pick up the new config.** Hyprland is the default
  generation on every host (no specialisation since the GNOME rip-out,
  2026-07-12). After a `switch`, relaunch `qs` to load the newly generated
  config — or just reboot. Caveat: switching the machine Claude is running on
  has its own hazards (dry-activate first; commit+push before switching — see
  memory "switch on host kills session").

- **`pragma Singleton` goes on line 1, above all comments.** Quickshell's
  singleton scan stops at the first `{` in the file *even inside a comment*;
  a missed pragma is silent — the file registers as a plain type, `qs -p`
  loads clean, and every property read off the name yields `undefined`
  (the center-island "· undefined" bug, 2026-08-03).

**Quickshell 0.3.x API gotchas** (UPower percentage is 0..1 not 0..100, MPRIS
`trackArtist` singular + non-reactive `position`, Pipewire volume needs
`PwObjectTracker`, `notif.tracked = true` or notifications are freed,
`Quickshell.iconPath(name, true)` for an existence-checked path, SystemTray
needs the `//@ pragma UseQApplication` in `shell.qml`, no `QtQuick.Controls`):
the full verified list is in `docs/plans/2026-07-10-hyprland-handoff.md`
(“Quickshell API gotchas”). Read it before reaching for an unfamiliar type.
