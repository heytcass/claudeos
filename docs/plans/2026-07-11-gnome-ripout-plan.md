# GNOME rip-out: Hyprland becomes the default (2026-07-11)

Decided with Tom in-session. Supersedes the "GNOME stays the default" framing
of `2026-07-10-wm-evaluation-report.md` — the specialisation trial convinced
him; Hyprland + the bespoke Quickshell bar is the direction. GNOME gets
removed entirely, in phases.

## Decisions (locked)

| Question | Decision |
|---|---|
| Login manager | **greetd + regreet** (GTK4 → Stylix-themed, cage kiosk compositor). A bespoke QML greeter on SDDM was seriously considered and stays on the table as a *later, separate project* — the DM is a one-module swap, cheap to revisit. |
| File manager | **Nautilus standalone** (`pkgs.nautilus` + `services.gvfs`) — keeps the Ghostty context-menu extension and the ClaudeOS folder-icon theme. |
| Rollout | **Invert the specialisation**: Hyprland becomes transporter's default generation, GNOME becomes the fallback boot entry for a burn-in period, then gets deleted. gti follows at its reinstall. |
| Small GNOME apps | **Keep the good ones standalone**: gnome-calculator, Loupe, file-roller. Weather, Maps, Contacts, Clocks, etc. simply go (they only exist because `desktopManager.gnome.enable` installs them). |
| Secret Service | **Keep gnome-keyring** — it's a daemon + libsecret, not "GNOME". Enable `services.gnome.gnome-keyring` explicitly; unlock via `security.pam.services.greetd.enableGnomeKeyring = true`. |

Rationale for greetd+regreet over SDDM: born-Wayland vs ported-to-Wayland;
regreet's greeter compositor is cage (tiny, wlroots — same family as the rest
of the stack) while SDDM-Wayland's NixOS default pulls Weston; regreet is GTK4
so Stylix themes it for free, whereas Stylix has no SDDM target and community
QML themes are largely X11-era.

## What the specialisation already replaced (done, verified in-session)

Launcher (fuzzel), notifications (Quickshell's own o.f.Notifications server),
lock/idle (hyprlock/hypridle), wallpaper (hyprpaper), media/brightness keys
(binds + wpctl/brightnessctl/playerctl), screenshots (grim/slurp via the
session-aware wrapper), polkit agent (soteria), portals (hyprland + gtk
fallback), tray (Quickshell SystemTray), Qt presence (Quickshell ships Qt6).

## Phase 0 — close the gsd gaps *before* flipping the default

GNOME's settings-daemon quietly provides these today; the Hyprland session
must own them before it's the daily driver:

- [ ] **Suspend-on-battery**: gnome.nix policy is "AC: stay awake (overnight
      automation), battery: suspend after 20 min". hypridle currently has NO
      suspend listener. Add one (script the AC check via
      `/sys/class/power_supply/*/online` or upower) + confirm logind lid
      handling matches.
- [ ] **Night light**: gsd's dies with GNOME → `wlsunset` (simplest, trusted;
      geoclue stays — it's freedesktop, not GNOME). `hyprsunset` is the
      ecosystem-native alternative if wlsunset disappoints.
- [ ] **Input parity**: key repeat 250ms/25ms and tap-to-click from
      home/gnome.nix dconf → Hyprland `input { repeat_delay/repeat_rate,
      touchpad { tap-to-click } }`.
- [ ] **Qt theming** — MOVED TO PHASE 1: home/gnome.nix (co-imported in the
      specialisation) hard-sets the adwaita Qt platform theme; overriding it
      with mkForce across co-imported modules is messier than waiting until
      the inversion stops importing gnome.nix into the Hyprland generation.
      Then: enable Stylix's Qt target, delete the adwaita-qt hand-roll.
- [ ] **Caffeine replacement**: bar toggle for idle-inhibit (Hyprland
      idle-inhibit / systemd-inhibit) — long agent runs must not lock
      mid-flight.
- [ ] **greetd + regreet module**: `programs.regreet.enable` (pulls greetd,
      runs under cage). Colemak at the greeter: set XKB env
      (`XKB_DEFAULT_LAYOUT=us`, `XKB_DEFAULT_VARIANT=colemak`) for the cage
      session — replaces the GDM-specific fix documented in locale.nix.
      Keyring: `security.pam.services.greetd.enableGnomeKeyring = true`
      (replaces the GDM PAM substack ride documented in
      modules/desktop/hyprland.nix).
- [ ] **Explicit keyring service**: `services.gnome.gnome-keyring.enable =
      true` in the Hyprland module (today it's inherited from GNOME).

## Phase 1 — invert the specialisation (transporter)

- [ ] Gate GNOME behind an option like Hyprland already is:
      `claude-os.gnome.enable` mirroring `claude-os.hyprland.enable`
      (modules/desktop/gnome.nix currently hard-enables).
- [ ] transporter default generation: hyprland on, greetd/regreet as DM,
      home/hyprland.nix imported normally.
      `specialisation.gnome` = GDM + GNOME as the fallback boot entry.
- [ ] gti: keeps GNOME default until reinstall (both modules stay gated, host
      picks — flake must keep building for both hosts).
- [ ] Move the `hideDesktopEntries` package out of gnome.nix into a shared
      spot — fuzzel reads the same .desktop entries. Fix TWO confirmed bugs
      while moving it (verified in-session 2026-07-11 by tracing
      XDG_DATA_DIRS):
      1. *Profile precedence*: btop and zathura live in home-manager's
         per-user profile (`/etc/profiles/per-user/tom/share`), which
         precedes `/run/current-system/sw/share` — so the system-level
         NoDisplay override LOSES and they show in the launcher anyway.
         Hides for home-managed packages must be applied at the HM layer
         (e.g. `xdg.desktopEntries`/data-file overrides in `~/.local/share`,
         which outranks everything).
      2. *ID mismatch*: Chrome's real entry is `google-chrome.desktop`, but
         the hide list targets `com.google.Chrome` — the override hides a
         nonexistent ID and Chrome shows.
- [ ] Nautilus standalone in the Hyprland generation: `pkgs.nautilus`,
      `services.gvfs`, `nautilus-python` + verify the Ghostty context-menu
      extension still loads outside GNOME (may need the extension dir linked).
- [ ] Standalone apps: gnome-calculator, loupe, file-roller, zenity (stays —
      claude-ask-desktop), mpv for video. Optional keepers to decide during
      the flip (all run fine standalone): seahorse (GUI for the gnome-keyring
      we're keeping), GNOME Disks (USB/SMART), simple-scan (if a scanner
      exists). Default: leave them out, add back if missed.
- [ ] Settings replacements on PATH: pavucontrol, blueman,
      nm-connection-editor (windowrules already float all three),
      nwg-displays or kanshi for monitors.
- [ ] Deploy caution: the "rebuild switch breaks Hyprland specialisation"
      memory INVERTS after this — switch will then activate Hyprland and
      strip a running GNOME fallback session, not vice versa. Boot-into
      remains the safe path during the flip itself.

## Phase 2 — burn-in checklist (a week-ish on the inverted default)

Keyring unlocks at greetd login (Claude/Chrome save logins) · file pickers in
Claude Desktop · screenshare with picker · suspend on battery + lid ·
stay-awake on AC (overnight automation actually runs) · night light ramps ·
tray icons · notifications · Colemak at greeter · bluetooth/audio UIs ·
external monitor on gti-class HiDPI (fractional scale per-monitor) · Ghostty
context menu in Nautilus.

## Phase 3 — the rip-out

- [ ] Delete `specialisation.gnome`, modules/desktop/gnome.nix,
      home/gnome.nix (dconf tree dies with it).
- [ ] theme.nix: delete the gnome-shell gresource surgery (~100 lines: shell
      theme rebuild, GDM stylesheet, User Theme override). ClaudeOS icon
      theme and all GTK/Stylix theming stay.
- [ ] modules/common/system.nix: collapse the session-aware claude-screenshot
      wrapper to grim-only; drop gnome-screenshot.
- [ ] locale.nix: drop the GDM-greeter Colemak note/workaround.
- [ ] Update PHILOSOPHY.md (the 2026-06 "GNOME over Niri" conclusion) and
      CLAUDE.md's Environment line, same PR.
- [ ] Update memory files that encode GNOME-era facts (gnome-screenshot D-Bus,
      rebuild-switch-breaks-specialisation, specialisation-env — all invert or
      expire).
- [ ] gti reinstall inherits Hyprland-as-default with no GNOME ever installed.

## Deferred / future

- **oo7-daemon as the gnome-keyring successor**: Rust reimplementation of the
  Secret Service, same D-Bus API, reads gnome-keyring's keyring format —
  GNOME's own intended replacement, so it's the natural "last GNOME-C daemon
  leaves" step. NOT actionable yet: the locked nixpkgs ships only `oo7`
  0.6.0 (CLI, verified 2026-07-11 — no daemon package), and its PAM
  auto-unlock story is younger than pam_gnome_keyring's. Re-check when
  nixpkgs grows an oo7-daemon package; trial on transporter first.
- Trim gnome-keyring components: exec-once starts `secrets,ssh,pkcs11` — if
  the ssh-agent and pkcs11 components are unused (git signs with a plain SSH
  key), slim to `--components=secrets`.
- Bespoke QML greeter (SDDM or greetd-native QML greeter) as its own project.
- Bar growth: network menu, idle-inhibit toggle, display switcher — replacing
  the last reasons to open a "settings app" at all.
