# Tiling WM Evaluation — Hyprland vs Niri vs Mango (+ shell tooling)

*2026-07-10. Compiled from a four-agent research sweep (Hyprland, Niri, Mango,
Quickshell/bar ecosystem) plus a read of this repo's own scar tissue in
`docs/PHILOSOPHY.md`. Every version/feature claim is sourced inline. Verdicts:
✅ recommend · 🟡 viable-with-caveats · 🧪 experiment-only · ❌ not now.*

**Brief (Tom, 2026-07-10):** "WM itch again. Hyprland's changed a lot, there's
also Mango and Niri. Look at the current state of all of them, mine the repo
for the pain points I've hit before, and recommend what fits ClaudeOS —
including support tooling (Noctalia vs DMS or newer options)."

**Answers that scoped this report:** the itch is **ricing/aesthetics + specific
GNOME dissatisfaction**; the scope is a **boot-menu specialisation on
`transporter`** (testbed, GNOME stays default on `gti`); integration tolerance
is **"some"** (a few rough edges are fine if the payoff is good and Claude can
paper over them); shell tooling is **"you recommend."**

---

## Synthesis / recommendation up front

**Go Hyprland, on `transporter`, as a specialisation, paired with
DankMaterialShell driven by your existing Stylix palette.** Add **Mango as a
second, throwaway specialisation** if the novelty itch wants feeding. **Skip
Niri this round** — not because it's bad (it's matured a lot), but because the
*specific* seams that burned you in March are still open, and its spartan
aesthetic is the weakest fit for a ricing goal.

Why this and not the others, in one paragraph each:

- **Hyprland ✅** — it is the ricing capital of the Wayland world (deepest
  built-in blur/shadow/animation/glow, biggest dotfiles community), and,
  critically, it **closes the exact integration wounds that killed ClaudeOS 1.0
  on Niri**: native screencast *with a picker*, native global shortcuts, a
  one-line GTK file-picker portal, and mainstream-tested Electron/Chromium.
  Best-in-class NixOS support. The price is periodic config churn and the
  Vaxry/freedesktop governance baggage — neither of which is a blocker for a
  testbed specialisation.
- **Mango 🧪** — the fun one. dwl-lean C compositor with SceneFX eye-candy, a
  real IPC (`mmsg`), hot-reloadable text config, and first-class Nix modules.
  Genuinely delightful and very on-brand for "bleeding-edge plumbing on
  purpose" — but it's ~18 months old with a **bus factor of ~1**, and its
  wlroots + `xdg-desktop-portal-wlr` stack has the *same class* of portal
  roughness that bit you before. Perfect as a disposable second specialisation;
  wrong as anything load-bearing.
- **Niri 🟡** — matured impressively (overview, floating, alt-tab, mainline
  blur), and its NixOS/Stylix story is now excellent. But the three things that
  actually made it "feel like fighting it" — Wayland→X11 drag-and-drop, X11
  clipboard sharing, hand-assembled portal backends — are **still open or still
  manual in mid-2026**. You already ran this experiment. Repeating it fights a
  ricing goal with the most deliberately-minimal compositor of the three.

**Support tooling: DankMaterialShell (DMS).** It is the only modern integrated
shell with a **native Stylix target** (`stylix.targets.dank-material-shell`),
which means your hand-authored claude.ai base16 palette *drives* the shell
instead of being overridden by a wallpaper-derived Material-You engine. That
single fact resolves the tooling question against Noctalia (no Stylix target,
manual sync) and Caelestia (Hyprland-locked, color engine fights Stylix).
**Waybar** stays in your back pocket as the zero-risk fallback (also a native
Stylix target) if DMS's pre-1.0 Quickshell foundation misbehaves.

The whole thing is philosophy-legal: it's a **specialisation, not a rewrite**
(§ Taste: "Compositor experiments return as specialisations"); it lands on
**`transporter` first** (testbed-before-primary); and your proactive layer
survives the swap untouched because it's already **DE-agnostic** — Morning Desk
is a file, openers are URLs, notifications are libnotify.

---

## Part 1 — The pain-point pattern, mined from this repo

The repo is unusually honest about why the tiling experiment failed the first
time. From `docs/PHILOSOPHY.md` ("Why this exists (and why it failed once)"):

> ClaudeOS was abandoned for Ubuntu in March 2026. … **Integration pain** —
> file pickers, drag-and-drop, the Chrome extension, the VSCode extension all
> worked worse than on Ubuntu. Root causes: **a niche compositor (Niri)** and
> FHS assumptions in fast-moving proprietary tools.

And from the GNOME decision itself (`modules/desktop/gnome.nix` header, and the
Taste section):

> GNOME today (chosen 2026-06: familiarity and first-class app integration beat
> Niri, which "felt like fighting it").

So the historical pattern is precise and worth naming, because it's the rubric
every option below is graded against:

1. **The wound was never the tiling paradigm — it was the OS seams.** Nothing
   in the postmortem says "scrolling windows were bad." Every named failure is
   an *integration* boundary: file picker (portal), drag-and-drop (Wayland↔X11),
   Chrome extension (native-messaging/XWayland), VSCode (XWayland keymap). This
   matters enormously: it means the fix isn't "pick a tiler you'll like more,"
   it's "pick a tiler whose **portal + XWayland story is solid**."
2. **"Felt like fighting it" = assembly burden + niche blast radius.** Niri in
   early 2026 made you hand-wire the desktop and then absorbed every
   proprietary-app quirk as a first-time discovery. A bigger-community
   compositor turns those into solved, googleable, already-in-the-wiki
   problems.
3. **Declarative friction is a *separate* wound, and it's already solved.** The
   other March root cause was Nix force-managing fast-moving layers (VSCode
   extensions, MCP configs). The two-ring rule fixed that; a WM is squarely
   ring 1 (declarative, rebuilt), so a compositor swap does **not** reopen that
   wound. Good — it means we only have to clear bar #1 (integration), not #2.

The repo also already anticipated this exact session. `docs/plans/next-session-prompts.md`
lists, as open backlog item **#5, "Hyprland specialisation — dormant by
choice."** This report is that item waking up.

**Implication for grading:** an option passes only if its **portal/XWayland
integration is materially better than Niri-in-March**. That's the whole ball
game, and it's why Hyprland wins and Mango is quarantined to "experiment."

---

## Part 2 — Compositor current state (mid-2026)

### Hyprland ✅ — the ricing king that also fixed the seams

**Where it is now.** Current release **v0.55.4 (2026-06-11)**; roughly a feature
release every 4–8 weeks with point releases between
([releases](https://github.com/hyprwm/Hyprland/releases),
[Phoronix 0.55](https://www.phoronix.com/news/Hyprland-0.55-Wayland-Comp)). Two
architectural events dominate the 2024→2026 story:

- **v0.42 (Aug 2024): full independence from wlroots.** Hyprland replaced
  wlroots with its own stack — **aquamarine** (backend) + **hyprland-protocols**
  + in-house renderer — and added explicit-sync. Reported as largely seamless
  for users
  ([Phoronix 0.42](https://www.phoronix.com/news/Hyprland-0.42-Wayland),
  [Linuxiac](https://linuxiac.com/hyprland-completes-independence-from-wlroots/)).
  Ironically, this *insulated* the project from the freedesktop dispute below —
  it no longer depends on upstreaming into wlroots/FDO.
- **v0.55 (2026): Lua-backed config engine + a user Layout API.** The everyday
  `hyprland.conf` surface stays familiar, but config is now Lua-backed, which
  is why some older dotfiles/tutorials are stale
  ([Phoronix 0.55](https://www.phoronix.com/news/Hyprland-0.55-Wayland-Comp)).

**Integration (the part that matters for us).** This is where Hyprland decisively
beats Niri-in-March:

- **Screencast: native, with a graphical picker** (full-screen / per-window /
  region) via `xdg-desktop-portal-hyprland`
  ([XDPH wiki](https://wiki.hypr.land/Hypr-Ecosystem/xdg-desktop-portal-hyprland/)).
- **Global shortcuts: native** — the GlobalShortcuts portal is implemented, so
  Discord/browser push-to-talk and Flatpak shortcuts work. A gap Niri and
  several wlroots compositors historically lacked.
- **File picker: one-line add** — XDPH deliberately doesn't ship a FileChooser;
  you compose `xdg-desktop-portal-gtk` alongside it (`xdg.portal.extraPortals`
  on NixOS). Standard, documented, reliable.
- **Drag-and-drop / Chrome / VSCode / Electron:** behave, because Chromium's
  Wayland path is mainstream-tested against Hyprland specifically.

**NixOS fit — best-in-class.** Two paths, and for us the choice is clear:

- **Use `programs.hyprland` from nixpkgs** (ClaudeOS already tracks unstable),
  optionally `withUWSM = true`. No recompile, and — importantly — **Mesa always
  matches the system**, which sidesteps the notorious "flake Hyprland + stable
  Mesa = GPU lag" glitch entirely
  ([NixOS Wiki](https://wiki.nixos.org/wiki/Hyprland),
  [Discourse](https://discourse.nixos.org/t/flakes-hyprland-and-hyprland-plugins-version-mismatch/38834)).
- Only switch to the official flake if you want a plugin or a release newer than
  unstable; then wire plugins via home-manager
  `wayland.windowManager.hyprland.plugins` with
  `inputs.hyprland-plugins.inputs.hyprland.follows = "hyprland"` so the plugin
  builds against your exact locked Hyprland — this is the mechanism that kills
  ABI mismatch ([Nix plugins wiki](https://wiki.hypr.land/Nix/Plugins/)).
- home-manager `wayland.windowManager.hyprland.settings` maps Nix attrsets →
  config declaratively, so Stylix colors inject cleanly
  (`config.lib.stylix.colors`, honoring the CLAUDE.md "never hardcode hex"
  rule).

**Ricing — the headline.** Deepest built-in eye-candy of any tiler: configurable
blur, rounded corners, opacity, shadows, a **glow** decoration (~0.55), and a
full Bézier/spring animation system
([decorations wiki](https://deepwiki.com/hyprwm/hyprland-wiki/3.10-decorations-and-animations)).
Flagship plugins actively maintained in 2026: **hyprexpo** (exposé grid),
**Hyprspace** (workspace overview), and — note for your Niri muscle memory —
**hyprscrolling**, which gives a PaperWM/Niri-style scrolling layout *on top of*
Hyprland's mature integration
([official plugins](https://github.com/hyprwm/hyprland-plugins),
[Hyprspace](https://github.com/KZDKM/Hyprspace)). Largest rice community of any
tiling compositor, full stop.

**The honest costs.**

- **Config churn.** Keys deprecate/rename across releases (e.g. window-rule v2
  overhaul in 0.53; the Lua migration). A fully-declarative Nix config *fails
  loudly* at rebuild on a rename — arguably a feature here (you catch it in the
  PR, and the rung-2 gate would too), but budget an occasional config edit in
  the same bump.
- **Governance / politics.** Vaxry (creator) was **banned from freedesktop.org
  in April 2024** over a Code-of-Conduct matter tracing to a 2022 Discord
  incident; he argued Hyprland isn't an FDO project so FDO's CoC shouldn't
  reach it, critics disagreed, the community split
  ([DeVault](https://drewdevault.com/2024/04/09/2024-04-09-FDO-conduct-enforcement.html),
  [LibreNews](https://thelibre.news/hyprland-banned-from-freedesktop-why/)).
  None of it affects whether Hyprland *works* on the laptop. It matters only if
  (a) the maintainer's conduct bothers you on principle, or (b) you worry about
  long-term ecosystem cooperation. **If it does bother you, Niri is the
  clean-conscience pick** — flagging this rather than deciding it for you.
  Mitigating fact: as of 2025–26 Vaxry is more reviewer than sole author, so
  the bus factor is better than the figurehead implies
  ([Vaxry: Hyprland matures](https://blog.vaxry.net/articles/2025-hyprlandMatures)).

### Niri 🟡 — matured, but the same seams, and the wrong aesthetic for ricing

**Where it is now.** Moved to CalVer at v25.01; roughly quarterly. The desktop-feel
features you'd have wanted mostly landed *around or after* your trial: floating
windows (25.01), tabbed columns + shadows (25.02), **the Overview** (25.05),
xwayland-satellite integrated out-of-the-box (25.08), **Alt-Tab** (25.11),
**mainline background blur** (26.04, which also moved the repo to the `niri-wm`
org) ([releases](https://github.com/niri-wm/niri/releases),
[Phoronix 25.08](https://www.phoronix.com/news/Niri-25.08-Released)).

**The seams — still the deal-breaker.** This is the section that decides it:

- **Wayland→X11 drag-and-drop still doesn't work** — you cannot drag a file from
  a Wayland app into an XWayland app. Open and acknowledged
  ([discussion #2566](https://github.com/YaLTeR/niri/discussions/2566)).
- **X11 clipboard isn't shared** with rootful xwayland-satellite; the documented
  workaround is manual `wl-clipboard` piping
  ([Xwayland docs](https://niri-wm.github.io/niri/Xwayland.html)).
- **Portals are still assembly-required** — install `xdg-desktop-portal-gtk`
  *and* `xdg-desktop-portal-gnome`, route via `niri-portals.conf`, and know that
  the GNOME portal can *silently break* screencast in some configs
  ([issue #3798](https://github.com/niri-wm/niri/issues/3798)).

What genuinely improved is that Chrome/VSCode/Electron now run *native Wayland*
well enough to **avoid XWayland entirely** — but that's an avoidance strategy on
your side, not Niri closing the X11 gap. Given your history, that's exactly the
"felt like fighting it" texture, softened but not removed.

**NixOS/Stylix — excellent** (`sodiboo/niri-flake` with typed settings + a
binary cache + Stylix participation)
([niri-flake](https://github.com/sodiboo/niri-flake)). And ricing is now
*possible* (DMS pairs beautifully, blur is mainline). But the paradigm is
deliberately minimal, and for a stated **ricing** goal it's swimming upstream
compared to Hyprland. Verdict: reconsider *if* the scrollable paradigm itself is
what you miss; skip it if the goal is a striking rice and clean integration.

### Mango (mangowc) 🧪 — the delightful experiment, quarantined by bus factor

**What it actually is.** A tiling Wayland compositor **forked from dwl**
(dwm-for-Wayland), extended with **wlroots ~0.19 + SceneFX** for
blur/shadow/rounded-corners/animations, by a **solo developer (DreamMaoMao)**.
Renamed from `maomaowm`/`mangowc` to **Mango** (org `mangowm/mango`) in mid-2025
([repo](https://github.com/mangowm/mango),
[ArchWiki](https://wiki.archlinux.org/title/MangoWM)).

**Why it's tempting.** It nails the ClaudeOS "bleeding-edge plumbing on purpose"
taste: dwl-lean C core + eye-candy, a **hot-reloadable text config**
(`~/.config/mango/config.conf`, no recompile — a big usability jump over dwl), a
real **IPC** (`mmsg`, one-shot `get` + streaming `watch` JSON — great for a
custom bar), tags-not-workspaces with per-tag layouts including a PaperWM-style
scroller, and **first-class Nix modules** in-repo (`programs.mango.*`,
`wayland.windowManager.mango.*`)
([docs](https://mangowm.github.io/docs/),
[mmsg](https://github.com/DreamMaoMao/mmsg),
[flake](https://github.com/DreamMaoMao/mangowc/blob/main/flake.nix)). Actively
released (v0.15.1 dated 2026-07-10 — literally today), packaged across
Arch/Fedora/Gentoo/NixOS.

**Why it's not the recommendation.**

- **Bus factor ~1**, ~18 months old, ~150 open issues. The maintainer stepping
  away likely stalls it (mitigated only by the forkable dwl base).
- **Same portal class as your old pain:** it's wlroots + `xdg-desktop-portal-wlr`
  underneath, so screencast is whole-output-good/per-window-weak and file
  pickers need a hand-added `xdg-desktop-portal-gtk` — the *exact* assembly
  texture of March, just on a newer compositor.
- **Docs are second-language and uneven**; expect to read `config.conf`
  examples and occasionally the C source.

Verdict: **ideal as a disposable second specialisation** for an afternoon of
novelty, explicitly early-adopter tier, with a fallback session always one
boot-menu entry away. Never load-bearing.

**Compositor scorecard**

| | Hyprland ✅ | Niri 🟡 | Mango 🧪 |
|---|---|---|---|
| Ricing / built-in eye-candy | **Deepest** (blur/shadow/glow/anim) | Now capable (blur mainline 26.04) | Good (SceneFX) |
| Fixes the March seams? | **Yes** (native screencast+picker, global shortcuts, Electron) | **No** (W→X DnD, X clipboard still open) | **No** (wlroots/xdpw, same class) |
| Community / bus factor | Largest tiler community | Growing; effectively 1 lead | **~1** |
| NixOS support | Best-in-class (`programs.hyprland`) | Excellent (`niri-flake`) | Good (in-repo flake) |
| Config | Lua-backed `.conf`, declarative HM | KDL, typed HM settings | Hot-reload `.conf`, declarative HM |
| Governance risk | Vaxry/FDO baggage | Clean | Clean but tiny |
| Fit for *your* goals | **Best** | Weakest (you tried it; spartan) | Novelty only |

---

## Part 3 — Support tooling (the shell/bar layer)

The ecosystem consolidated hard around **Quickshell** (QtQuick/QML shell
framework by outfoxxed) — GPU-accelerated, hot-reload, rich Wayland integration.
The GTK-era stack (eww, AGS/Astal, fabric) is now legacy for new polished
builds. Standing caveat: **Quickshell is still pre-1.0 alpha and everything
built on it wants nixpkgs-unstable** — pin the flake inputs and update
deliberately
([quickshell install](https://quickshell.org/docs/guide/install-setup/)).

The decisive lens for ClaudeOS is your Stylix constraint: **`theme.nix` hand-authors
a claude.ai base16 scheme (terracotta `base0D = d97757`) and Stylix already
reaches into GNOME Shell's gresource to enforce it.** Whatever shell we pick must
*consume* that palette, not impose a parallel wallpaper-derived Material-You
engine. That ranks the field cleanly:

| Tool | Own color engine? | Consumes Stylix base16? | Verdict |
|---|---|---|---|
| **DankMaterialShell** | matugen/MD3 (default) | **Native Stylix target** `stylix.targets.dank-material-shell`; `DMS_DISABLE_MATUGEN=1`; custom JSON | **Best integrated shell for us** |
| **Waybar** | none | **Native Stylix target**; pure base16 CSS | **Cleanest / zero-risk fallback** |
| Noctalia | optional (matugen or fixed) | Custom scheme files, **no Stylix target** | Viable, but manual sync |
| Caelestia | wallpaper Material-You (central) | not designed for it | Fights Stylix; Hyprland-locked — avoid |
| eww / Astal / fabric | none (you write CSS) | hand-wired | legacy for new builds |

**Recommendation: DankMaterialShell (DMS).** It's the most mature of the new
shells (**v1.5.0, 2026-07-08**, ~7k stars, ~68 releases), a batteries-included
replacement for waybar+swaylock+swayidle+mako+fuzzel+polkit in one coherent
package, and — decisively — the **only new shell with a native Stylix target**,
so your base16 palette drives it and the Material-Design-3 token expansion is
handled *for you*. It's explicitly **niri-first and compositor-agnostic**
(Hyprland, Sway, Mango all supported with full workspace integration), so it
survives whichever compositor the specialisation lands on. Bonus tooling that's
useful even outside the shell: **`dgop`** (Go system-monitor daemon),
**`dank16`** (contrast-aware base16 generator), and the **`dms`** IPC CLI
([GitHub](https://github.com/AvengeMedia/DankMaterialShell),
[Stylix DMS target](https://nix-community.github.io/stylix/options/modules/dank-material-shell.html),
[NixOS flake install](https://danklinux.com/docs/1.5/dankmaterialshell/nixos-flake)).

**Fallback: Waybar.** If DMS's pre-1.0 Quickshell base proves too churny on a
testbed, Waybar is the boring, battle-tested bar with the cleanest possible
base16 story (`stylix.targets.waybar`) — at the cost of hand-assembling the rest
of the stack (mako/swaync + fuzzel/rofi + swaylock + swayidle + swww). Given
"some tolerance," start on DMS; keep Waybar as the known-good escape hatch.

**Not Noctalia (this round).** Genuinely polished (v5 beta), the widest
compositor list, good NixOS modules — but **no Stylix target**, so you'd
hand-generate its scheme file from your palette and re-sync it by hand on every
theme change. Against a Stylix-owns-color mandate, that's a papercut DMS simply
doesn't have.

---

## Part 4 — How it slots into ClaudeOS (concrete)

This stays inside the philosophy: specialisation, testbed-first, DE-agnostic
core, reversible.

1. **New module, off by default.** `modules/desktop/hyprland.nix` guarded so it
   contributes nothing unless a host opts in — mirroring how `gnome.nix` is
   structured. Colors come exclusively from `config.lib.stylix.colors` (CLAUDE.md
   mandate); no hardcoded hex.
2. **Expose it as a boot-menu specialisation on `transporter`.** A
   `specialisation.hyprland = { … };` block gives you a GDM/boot entry that
   boots Hyprland while the default generation stays GNOME. This is the exact
   "compositor experiments return as specialisations, not rewrites" mechanism
   the Taste section calls for, and its blast radius has a floor NixOS gives for
   free — the previous generation is one reboot away. (Note: there is currently
   **no** specialisation scaffolding in the repo — the only `specialisation`
   string is the comment in `gnome.nix`. This is greenfield.)
3. **Portal stack, declared.** `programs.hyprland.enable` (from unstable, so
   Mesa matches) pulls XDPH; add `xdg-desktop-portal-gtk` via
   `xdg.portal.extraPortals` for the file chooser. Set
   `XDG_CURRENT_DESKTOP=Hyprland`.
4. **Shell layer via the DMS flake + home-manager module**, with
   `stylix.targets.dank-material-shell.enable = true` so the terracotta palette
   drives it. Pin the DMS/Quickshell inputs; update deliberately, not on HEAD.
5. **Validate the ClaudeOS way** before it ever touches `gti`: `nix build
   .#nixosConfigurations.transporter…`, `nix flake check`, `nix fmt`, then live
   on it on the Latitude. Only after it earns its keep does a `gti`
   specialisation get considered — never a GNOME replacement on the primary
   without a separate, deliberate decision.

**What does *not* change, by design:** Morning Desk, the journal diary, the
weekly update, notifications — all DE-agnostic (files, URLs, libnotify), so the
proactive layer rides along untouched. That's the payoff of the "desktop
environment is a replaceable organ" doctrine: this is an organ swap, not
surgery on the nervous system.

---

## One open question that would sharpen the tuning

You flagged **"GNOME dissatisfaction"** as a driver but didn't say *what*
specifically annoys you. It won't change the compositor pick, but it steers the
config: if it's **mouse-heaviness / workflow friction**, we lean into
keyboard-first binds and hyprexpo; if it's **RAM / weight**, Hyprland is already
a big win and we'd keep the shell lean; if it's a **specific GNOME behavior**
(workspace model, animations, tray), we'd target that directly. Tell me which
and I'll bake it into the module. (Not blocking — the recommendation stands
either way.)

---

## Sources

**Hyprland:** [releases](https://github.com/hyprwm/Hyprland/releases) ·
[Phoronix 0.55](https://www.phoronix.com/news/Hyprland-0.55-Wayland-Comp) ·
[Phoronix 0.42](https://www.phoronix.com/news/Hyprland-0.42-Wayland) ·
[independence writeup](https://linuxiac.com/hyprland-completes-independence-from-wlroots/) ·
[XDPH wiki](https://wiki.hypr.land/Hypr-Ecosystem/xdg-desktop-portal-hyprland/) ·
[NixOS Wiki](https://wiki.nixos.org/wiki/Hyprland) ·
[Nix plugins](https://wiki.hypr.land/Nix/Plugins/) ·
[version-mismatch Discourse](https://discourse.nixos.org/t/flakes-hyprland-and-hyprland-plugins-version-mismatch/38834) ·
[decorations/animations](https://deepwiki.com/hyprwm/hyprland-wiki/3.10-decorations-and-animations) ·
[official plugins](https://github.com/hyprwm/hyprland-plugins) ·
[Hyprspace](https://github.com/KZDKM/Hyprspace) ·
[DeVault on FDO](https://drewdevault.com/2024/04/09/2024-04-09-FDO-conduct-enforcement.html) ·
[LibreNews](https://thelibre.news/hyprland-banned-from-freedesktop-why/) ·
[Vaxry: Hyprland matures](https://blog.vaxry.net/articles/2025-hyprlandMatures)

**Niri:** [releases](https://github.com/niri-wm/niri/releases) ·
[Xwayland docs](https://niri-wm.github.io/niri/Xwayland.html) ·
[W→X DnD #2566](https://github.com/YaLTeR/niri/discussions/2566) ·
[screencast portal #3798](https://github.com/niri-wm/niri/issues/3798) ·
[Phoronix 25.08](https://www.phoronix.com/news/Niri-25.08-Released) ·
[niri-flake](https://github.com/sodiboo/niri-flake) ·
[6-month review](https://itsfoss.com/niri-window-manager/)

**Mango:** [repo](https://github.com/mangowm/mango) ·
[docs](https://mangowm.github.io/docs/) ·
[mmsg IPC](https://github.com/DreamMaoMao/mmsg) ·
[flake](https://github.com/DreamMaoMao/mangowc/blob/main/flake.nix) ·
[ArchWiki](https://wiki.archlinux.org/title/MangoWM) ·
[LinuxLinks](https://www.linuxlinks.com/mangowc-wayland-compositor/)

**Shell tooling:** [Quickshell](https://quickshell.org/docs/guide/install-setup/) ·
[DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) ·
[DMS overview](https://danklinux.com/docs/dankmaterialshell/overview) ·
[Stylix DMS target](https://nix-community.github.io/stylix/options/modules/dank-material-shell.html) ·
[DMS NixOS flake](https://danklinux.com/docs/1.5/dankmaterialshell/nixos-flake) ·
[Noctalia](https://github.com/noctalia-dev/noctalia) ·
[Noctalia NixOS wiki](https://wiki.nixos.org/wiki/Noctalia_Shell) ·
[Caelestia](https://github.com/caelestia-dots/shell)
