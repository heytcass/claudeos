---
name: qml-dial-in
description: Iterate on the bespoke Quickshell/Hyprland bar visually — animations, spacing, colours, layout. Runs the edit → fast-reload → screenshot → review loop without a full NixOS rebuild. Use when tweaking anything under home/quickshell/*.qml.
---

# Quickshell bar visual dial-in

Tight visual iteration on the bar in `home/quickshell/*.qml` **without** a
rebuild per change. You must be running **inside the Hyprland session** (grim
only works under Hyprland, not GNOME — verify with `pgrep -x Hyprland` or that
`hyprctl` responds). Read `.claude/rules/quickshell-qml.md` and the API gotchas
in `docs/plans/2026-07-10-hyprland-handoff.md` first.

## The loop

### 1. Edit the source
Edit the `.qml` files in `home/quickshell/` (the real source — the preview reads
from here, so there's no separate "port back" step).

### 2. Fast-reload + screenshot
```bash
qml-preview            # copies deployed config + overlays repo QML, relaunches, screenshots
```
It writes the shot to `/tmp/qs-preview.png` and **exits non-zero on a QML load
error** (printing the offending file:line). If `qml-preview` isn't on PATH yet
(needs one rebuild to install), run the script directly:
`~/.config/claudeos/home/qml-preview.sh`.

Under the hood it: copies the *deployed* `~/.config/quickshell` (for the
generated `Theme.qml` + `cava.conf`), overlays the repo's `home/quickshell/*.qml`
into `/tmp/qs-preview`, stops the running bar, launches `qs -p`, and grabs a
screenshot. The next `rebuild` restores the real bar.

### 3. Review
`Read` `/tmp/qs-preview.png`. To inspect one region (e.g. just the island),
re-grab it: `grim -g "400,0 480x40" /tmp/qs-region.png` (coords are logical px;
the bar is `Theme.barHeight` tall at the top). For animations, grab 2–3 frames a
beat apart to confirm motion.

To exercise a state that isn't currently true, drive it directly rather than
faking it in the QML:
- **media/spectrum**: play audio (any MPRIS source); or briefly force the island
  `state`/`active` in the `/tmp/qs-preview` copy.
- **notification peek / toast**: `gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.Notify "App" 0 "" "Summary" "Body" "[]" "{}" 5000`
- **agent pulse**: `touch "$XDG_RUNTIME_DIR/claudeos-agent"` (remove to clear).

### 4. Iterate
Tweak, re-run `qml-preview`, re-review. Keep the loop tight — seconds, not a
rebuild.

### 5. Bake it in
When happy: `nix build .#nixosConfigurations.transporter.config.system.build.toplevel`
(+ `nix fmt`), commit, then **`rebuild` → reboot into the `(hyprland)` boot
entry** (a `switch` won't deploy the specialisation). Restore the live bar
meanwhile by relaunching `qs` (or just reboot).

## Gotchas (see the rule file for the full set)
- One broken `.qml` blanks the entire bar — always check the reload log.
- Stylix base16 only; never hardcode hex.
- `Theme.qml`/`cava.conf` are generated — that's why the preview copies the
  deployed dir rather than running the repo dir directly.
