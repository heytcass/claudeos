# Quickshell greeter — replacing regreet

**Status:** proposed (2026-08-15)
**Supersedes:** the greeter half of `services.displayManager.regreet.enable`
in `modules/desktop/hyprland.nix`
**Prompted by:** evaluation of [Nitrux/qmlgreet](https://github.com/Nitrux/qmlgreet)
as a regreet replacement

---

## The question that started this

> "Should we use qmlgreet for our greeter? I'm not a fan of greetd so far."

Two complaints, separable: **regreet looks wrong next to the bar**, and
**the login screen is unreliable/slow**. They need different fixes, and only
one of them is a greeter problem.

## Why not qmlgreet

qmlgreet is a **greetd greeter**, not a greetd replacement — it occupies
exactly regreet's slot. Adopting it changes the UI and nothing else. On the
merits for this repo:

| Factor | Finding |
|---|---|
| Packaging | Not in nixpkgs. Needs a hand-written derivation, plus MauiKit ≥ 4.0.3 (Qt6 ≥ 6.9.2) — MauiKit 4.x packaging status unverified; may need packaging too. |
| Support | README states it targets Nitrux OS and is **unsupported elsewhere**. Ships x86-64-v3 optimizations. |
| Theming | Configured via `/etc/qmlgreet/qmlgreet.conf`. We would hand-render base16 into a generated conf and own that mapping forever. |
| Stylix | Loses the auto-enabled regreet target that currently drives wallpaper, GTK CSS, font, and cursor from one source (`modules/desktop/hyprland.nix:70-74`). |

We'd take on a foreign toolkit and a bespoke theme bridge to get a QML greeter
— when we already have a QML shell, a QML palette pipeline, and a QML load-check
tool in-tree.

## The decision

**Build the greeter in Quickshell**, using `Quickshell.Services.Greetd`.

The runtime shape is structurally identical to today's:

```
today:     greetd → cage → regreet     (GTK4)
proposed:  greetd → cage → quickshell  (QML, Quickshell.Services.Greetd)
```

greetd stays. `cage` stays. Only the process inside the kiosk changes.

### Why this fits ClaudeOS specifically

- **The palette pipeline already exists.** `home/hyprland.nix:93-148` generates
  `Theme.qml` from `config.lib.stylix.colors` + `lib/theme.nix`. The greeter
  reads the same generated singleton, so the login screen matches the bar *by
  construction* — no second theme bridge to keep in sync.
- **No new packaging.** `pkgs.quickshell` is already a system package
  (`home/hyprland.nix:543`).
- **Validation tooling already exists.** The `system-health` MCP server's
  `quickshell_check` load-checks a QML dir with `qs -p`; `/qml-dial-in` is the
  edit → reload → screenshot loop. Both apply unchanged to greeter QML.
- **Design language carries over.** 37 QML files' worth of established idiom
  (`Pill.qml`, `Island.qml`, card surfaces) is directly reusable.

### Ring placement

Ring 1 — declarative. The greeter is boot/security-posture surface; Nix owns
it and the repo is truth. No ring-2 mutable state is introduced.

---

## The reliability complaint is probably not regreet

Worth stating plainly, because a prettier greeter will not fix a hardware bug.

**Already root-caused and fixed:** the "greetd locks up if you don't log in
within a couple minutes" symptom (3 boots on `transporter`, 1 on `gti`) was
Intel Panel Self Refresh freezing the eDP panel on a fully static screen. Fixed
fleet-wide with `i915.enable_psr=0` in `modules/common/boot.nix:30-42`. Not a
greeter defect.

**Open hypothesis for the slowness:** Stylix points the regreet background at
`assets/dune.jpg` — 674 KB, but a 3840² canvas per `modules/desktop/theme.nix:146-157`.
That is ~14.7 M pixels to JPEG-decode and rescale in GTK4, inside cage, on
2017-era Kaby Lake iGPUs, on every boot. Plausible; **not yet measured**.

**Action before implementing:** capture the actual numbers on `transporter`:

```
systemd-analyze blame | grep -i greetd
journalctl -b -u greetd --no-pager
```

If wallpaper decode dominates, a pre-scaled greeter background is the fix and
it applies to *either* greeter. The Quickshell greeter should ship a
panel-resolution asset regardless, rather than the 3840² master.

---

## Implementation sketch

### 1. Extract the Theme.qml generator (prerequisite)

`Theme.qml` generation currently lives inline in `home/hyprland.nix` (a
home-manager module). The greeter runs as the **`greeter` system user**, not
in the user's home-manager session, so it cannot reach that derivation.

Lift the generator into `lib/quickshell-theme.nix` as a function of
(`stylix colors`, `themeLib fonts`, metrics) returning the `Theme.qml` text.
Both call sites consume it:

- `home/hyprland.nix` — the bar (unchanged behavior)
- `modules/desktop/greeter.nix` — the greeter

One generator, no palette drift. `config.lib.stylix.colors` is available at the
NixOS level (already used that way in `modules/desktop/theme.nix:19`).

### 2. New module `modules/desktop/greeter.nix`

Option-gated as `claude-os.greeter.enable`, matching the `claude-os.hyprland`
pattern. Builds a greeter QML dir via `runCommand` (same shape as `qsConfig`)
and points greetd at it:

```
services.greetd.settings.default_session.command =
  "${cage} -s -- ${quickshell}/bin/quickshell -p ${greeterConfig}"
```

Replaces `services.displayManager.regreet.enable` at
`modules/desktop/hyprland.nix:75`.

### 3. Greeter QML

Minimum viable surface, in the bar's visual language:

- Wallpaper background (pre-scaled) + password field + user avatar
- **Session picker defaulting to "Hyprland (UWSM)"** — the plain entry strands
  `graphical-session.target` units and is a standing footgun
  (`modules/desktop/hyprland.nix:68-72`). A Quickshell greeter can simply not
  offer it, which removes the footgun rather than documenting it.
- A live clock — incidentally keeps the screen non-static, belt-and-braces
  against the PSR class of bug
- Auth flow: `createSession` → respond to prompts → `launch` on
  `GreetdState.ReadyToLaunch`

### 4. Things to verify on-machine (cannot be checked from Nix eval)

- [ ] `greeter` user has `video` + `input` group membership (Quickshell needs
      GPU/input access; regreet's module may have been providing this)
- [ ] `pam_gnome_keyring` on the greetd stack still unlocks the login keyring
      (`modules/desktop/hyprland.nix:85`) — this is auth-path, must not regress
- [ ] Colemak still applies at the greeter (`XKB_DEFAULT_VARIANT` via pam_env,
      `modules/desktop/hyprland.nix:54-63`) — **passwords get typed here**
- [ ] Session discovery via `XDG_DATA_DIRS` finds `hyprland-uwsm.desktop`

---

## Risk: this is the login screen

A broken QML file blanks the entire Quickshell config — the module registers
the config dir as one unit. In the bar that means "no bar." In the greeter that
means **no way to log in**.

Mitigations, all required:

1. **Prove on `transporter` first.** It is the testbed; `gti` is the daily driver.
2. **`quickshell_check` in CI-equivalent position** — the QML dir must load
   clean under `qs -p` before any `nixos-rebuild switch`.
3. **Keep a fallback.** greetd's `agreety` on a VT, or an unchanged prior
   generation in the boot menu, must remain reachable. Do not remove the
   regreet path until the Quickshell greeter has survived real use.
4. **`nixos-rebuild test` before `switch`** so a reboot recovers.

---

## Phasing

| Phase | Deliverable |
|---|---|
| 0 | Measure greeter startup on `transporter` (see above). Confirm or kill the wallpaper hypothesis. |
| 1 | Extract `lib/quickshell-theme.nix`; bar behavior unchanged. Independently shippable. |
| 2 | `modules/desktop/greeter.nix` + greeter QML, `transporter` only, regreet still default on `gti`. |
| 3 | Soak on `transporter`. Verify the four on-machine items. |
| 4 | Promote to `gti`; remove the regreet path; update `CLAUDE.md`, `docs/MODULES.md`, `INSTALL.md`. |

## Docs to update on completion

`CLAUDE.md` (the "Hyprland (UWSM)" greeter instruction and the Stack line),
`docs/MODULES.md`, `docs/DEPLOYMENT.md`, `INSTALL.md`, `README.md` — all
currently name regreet.
