# Module Documentation

Complete reference for all ClaudeOS NixOS configuration modules, generated from source.

## Architecture Overview

ClaudeOS is a NixOS flake. The entry point (`flake.nix`) defines two hosts -- `gti` (primary) and `transporter` (testbed) -- built via `lib/mkSystem.nix`. Every host automatically receives:

- **NixOS modules:** `modules/common/`, `modules/desktop/`, `modules/apps/`
- **home-manager** (as a NixOS module, not standalone): imports `home/default.nix`
- **Flake inputs:** home-manager, sops-nix, disko, stylix, nix-index-database (loaded as NixOS modules)
- **Per-host hardware module** from nixos-hardware
- `system.configurationRevision` set from `self.shortRev` (absent on dirty trees) — every generation traces back to its commit

The formatter is `nixfmt` via treefmt-nix (set in `flake.nix`).

### Flake Inputs

| Input | Source | Purpose |
|-------|--------|---------|
| nixpkgs | nixos-unstable | Package set and NixOS modules |
| home-manager | nix-community | User-level configuration |
| nixos-hardware | nixos | Hardware-specific quirks |
| sops-nix | Mic92 | Declarative secrets management |
| disko | nix-community | Declarative disk partitioning |
| stylix | danth | Unified theming (base16) |
| claude-desktop-linux | heytcass | Claude Desktop Electron app (follows main nixpkgs) |
| treefmt-nix | numtide | Formatter wiring for `nix fmt` |
| nix-index-database | nix-community | Prebuilt nix-index DB for comma (`, foo`) |

---

## lib/ -- Helper Library

### lib/default.nix

Exports the custom library. Currently exposes a single function:

- `mkSystem` -- imported from `lib/mkSystem.nix`

### lib/mkSystem.nix

Host builder function. Accepts `{ hostname, system, user, hardwareModules, modules, specialArgs }` and calls `lib.nixosSystem`.

Key behavior:
- Sets `nixpkgs.hostPlatform` and `networking.hostName` from arguments
- Configures home-manager as a NixOS module (`home-manager.useGlobalPkgs = true`, `home-manager.useUserPackages = true`)
- Imports `home/default.nix` as the home-manager config for the given user
- Sets `home-manager.backupFileExtension = "backup"` to auto-backup conflicting files
- Passes `inputs` and `user` through `specialArgs` and `home-manager.extraSpecialArgs`
- Always loads `modules/common`, `modules/desktop`, and `modules/apps`
- Appends `hardwareModules` and per-host `modules`

### lib/hideDesktopEntries.nix

Utility function that generates a derivation to hide `.desktop` entries from the application launcher. Takes `{ pkgs, lib }` and returns a function accepting a list of app names. Each name gets a `.desktop` file with `NoDisplay=true`, wrapped in `lib.hiPrio` so it takes precedence over real entries.

Used in both `modules/desktop/gnome.nix` (system-level) and `home/default.nix` (user-level).

### lib/theme.nix

Pure data file -- no packages, no imports. Central source of truth for font and icon names used across modules.

Contents:
- `colors` = `{ }` (reserved for future extended palette colors)
- `fonts.monospace.name` = `"JetBrains Mono"`, `fonts.monospace.nerdName` = `"JetBrains Mono Nerd Font"`
- `fonts.sansSerif.name` = `"Inter"`
- `fonts.serif.name` = `"Noto Serif"`
- `fonts.emoji.name` = `"Noto Color Emoji"`
- `fonts.symbols.name` = `"Symbols Nerd Font"`, `fonts.symbols.fallback` = `"Noto Sans Symbols 2"`
- `icons.name` = `"Adwaita"`

---

## modules/common/ -- Foundation

Core system configuration shared by all hosts. Imported via `modules/common/default.nix` which pulls in: `boot.nix`, `disko.nix`, `nix.nix`, `users.nix`, `networking.nix`, `locale.nix`, `system.nix`, `secrets.nix`, `snapshots.nix`, `auto-update.nix`, `generation-label.nix`, `self-heal.nix`. It also enables `claude-os.autoUpdate` (including `autoApply` — gated on a green VM smoke test) and `claude-os.selfHeal` by default (`lib.mkDefault`).

### modules/common/boot.nix

Boot loader and kernel configuration.

- **Bootloader:** systemd-boot (UEFI), `canTouchEfiVariables = true`
- **Generations:** limited to 10 (`configurationLimit = 10`) -- rollback headroom for an agent-maintained OS
- **Boot-entry editor:** disabled (`systemd-boot.editor = false`) -- prevents `init=/bin/sh` root shell via physical access
- **No Plymouth:** removed -- it pulled DRM drivers + firmware into every initrd (~60-90MB/generation on the ESP), trading rollback depth for a splash screen on a machine that boots in seconds via systemd-initrd
- **Silent boot:** kernel param `quiet`
- **Kernel:** latest (`linuxPackages_latest`, via `lib.mkDefault`)

### modules/common/disko.nix

Declarative disk layout via disko.

- **EFI partition:** 1G vfat, mounted at `/boot`
- **Root partition:** remainder of disk, btrfs with subvolumes:
  - `@` mounted at `/`
  - `@home` mounted at `/home`
  - `@nix` mounted at `/nix`
  - `@log` mounted at `/var/log`
- **Mount options:** `noatime`, `compress=zstd:3`, `ssd`, `discard=async`, `space_cache=v2`
- **Device:** no default -- each host must pin `disko.devices.disk.main.device` in `hosts/<name>/default.nix` (gti uses `/dev/nvme0n1`), so a new host fails evaluation instead of silently targeting the wrong drive
- `disko.enableConfig` defaults to `true`

### modules/common/nix.nix

Nix daemon and nixpkgs configuration.

- **Experimental features:** `nix-command`, `flakes`
- **XDG base directories:** enabled (`use-xdg-base-directories = true`)
- **Store optimization:** `auto-optimise-store = true`; `keep-outputs`/`keep-derivations` for faster rebuilds
- **Dirty warning:** suppressed (`warn-dirty = false`); global flake registry disabled
- **Trusted users:** `root`, `@wheel`
- **Substituters:** `cache.nixos.org`, `nix-community.cachix.org` (with corresponding public keys)
- **nh:** `programs.nh` enabled with `flake = /home/tom/.config/claudeos` — modern rebuild front-end (live build graph via nom, automatic closure diff on switch) and declarative GC (`clean.extraArgs = "--keep 5 --keep-since 14d"`, replaces `nix.gc.automatic`)
- **comma + nix-index-database:** `programs.nix-index-database.comma.enable = true` — `, foo` runs any nixpkgs program without installing it; `programs.command-not-found` disabled in its favor
- **Low-disk GC triggers:** `min-free` 1 GiB / `max-free` 5 GiB
- **Unfree packages:** allowed (`allowUnfree = true`)
- **State version:** `"24.11"` (`lib.mkDefault`)

### modules/common/users.nix

User account and shell setup.

- **User:** `tom` (normal user)
- **Groups:** `wheel`, `networkmanager`, `video`, `audio`, `dialout`, `kvm` (auto-update's VM smoke-test gate boots QEMU from a user unit)
- **Shell:** Fish (`pkgs.fish`)
- **SSH keys:** one ed25519 key authorized (`tom@ubuntu-dev`)
- **Fish:** enabled system-wide (`programs.fish.enable = true`)
- **Sudo:** sudo-rs (memory-safe Rust sudo) replaces the original sudo — `security.sudo.enable = false`, `security.sudo-rs.enable = true`, same wheel semantics, wheel requires password by default (`lib.mkDefault true`)

### modules/common/networking.nix

Network, DNS, firewall, and SSH.

- **NetworkManager:** enabled
- **systemd-resolved:** enabled with `DNSSEC = false` (upstream validation handled by local DNS server), `DNSOverTLS = "opportunistic"`, `LLMNR = false` (spoofable legacy protocol), fallback DNS `1.1.1.1` and `9.9.9.9`
- **Boot optimization:** `NetworkManager-wait-online` disabled
- **Firewall:** enabled, no ports opened by default
- **No fail2ban:** removed -- key-only sshd with a modern-crypto allowlist leaves nothing for it to protect on a roaming laptop; it was a resident daemon with mutable ban state (anti-ephemerality) that can ban *you* behind shared NATs
- **SSH server:** enabled, `PasswordAuthentication = false`, `PermitRootLogin = "no"`

### modules/common/locale.nix

Timezone, locale, and keyboard.

- **Timezone:** `America/New_York` (via `lib.mkDefault`)
- **Locale:** `en_US.UTF-8` for all `LC_*` categories
- **Console:** font `Lat2-Terminus16`, keymap `colemak`
- No `services.xserver.xkb` -- GNOME reads its keyboard layout from dconf (`home/gnome.nix` input-sources)

### modules/common/system.nix

System packages, hardware, and kernel tuning.

**Packages:**
- Basic: `vim`, `micro`, `wget`, `curl`, `htop`, `tree`, `file`, `unzip`, `zip`, `pciutils`, `usbutils`
- Network: `dig`, `traceroute`
- Nix dev: `nixfmt`, `statix`, `deadnix`, `nixd` (flake-aware Nix LSP; replaced unmaintained `nil`), `nvd` (closure diffs), `nix-output-monitor` (nom)
- Scripts: `claude-quick` (Super+C), `claude-ask-desktop` (Super+A, zenity prompt), `claude-screenshot` (Super+Shift+A), `claude-screenshot-interactive` (Super+Ctrl+A) — bound via GNOME custom keybindings in `home/gnome.nix`
- `supabase-cli` (Open Brain deployments)

**System configuration:**
- `services.envfs.enable = true` — FUSE filesystem on `/bin` and `/usr/bin` that resolves interpreters from the calling process's PATH; replaces the old hand-rolled `/bin/bash` activation symlink and fixes "works on Ubuntu, breaks on NixOS" third-party scripts
- `hardware.enableRedistributableFirmware = true`; Intel VA-API video acceleration (`intel-media-driver`)
- `services.fwupd.enable = true` (firmware updates)
- `services.thermald.enable = true` (Intel thermal management, `lib.mkDefault`); `services.power-profiles-daemon` and `services.upower` enabled
- `zramSwap.enable = true` (compressed in-memory swap)
- `services.scx` — `scx_lavd` BPF scheduler (sched_ext, Rust, Steam Deck lineage) with `--autopower`; kernel falls back to EEVDF instantly if it dies
- `services.dbus.implementation = "broker"` — dbus-broker (Fedora/Arch default), faster under chatty desktop IPC
- `systemd.oomd` enabled on root, user, and system slices
- `boot.tmp.useTmpfs = true` (tmpfs for /tmp)
- Kernel security sysctls: SysRq on, kptr/dmesg restricted, BPF JIT hardened + unprivileged BPF disabled, rp_filter, no ICMP redirects
- Polkit: wheel can manage systemd units without password (deliberately excludes manage-unit-files)
- auditd with rules for time changes and user/group database modifications
- `services.btrfs.autoScrub` enabled on `/`
- `services.fstrim.enable = true` — weekly TRIM for non-btrfs filesystems (e.g. the vfat ESP); btrfs trims continuously via `discard=async`

### modules/common/secrets.nix

Declarative secrets via sops-nix.

- **Sops file:** `secrets/secrets.yaml`
- **Decryption:** the host's SSH ed25519 key converted to age (sops-nix default `sshKeyPaths`) -- available during early boot, no user-home key file needed
- **Managed secrets** (all owner `tom`, mode `0400`): `jasper_anthropic_api_key`, `jasper_google_client_id`, `jasper_google_client_secret`, `jasper_google_weather_api_key`, `jasper_google_routes_api_key`, `jasper_home_address`
- `atuin_key` exists in `secrets.yaml` but is intentionally **not declared** -- atuin is local-only by decision (`home/shell/cli-tools.nix`)

See `docs/SECRETS.md` for editing/rotation workflow.

### modules/common/snapshots.nix

Snapper btrfs snapshot management.

- **Snapper:** enabled with hourly snapshot interval, daily cleanup, persistent timer
- **Root config:** SUBVOLUME `/`, timeline snapshots (hourly x 10, daily x 7, weekly x 2)
- **Home config:** SUBVOLUME `/home`, same retention, `ALLOW_USERS` includes the system user (no sudo needed)
- **Number cleanup** (both configs): `NUMBER_CLEANUP = true`, `NUMBER_LIMIT = 10`, `NUMBER_MIN_AGE = 1800`, `EMPTY_PRE_POST_CLEANUP = true` -- prunes the pre/post pairs created by the `rebuild` fish function so they don't pin deleted data forever

### modules/common/auto-update.nix

Weekly unattended flake updates with Claude review (`claude-os.autoUpdate`, enabled by default; `autoApply` on by default since 2026-06 — made safe by the VM smoke-test gate).

- **Timer:** `claudeos-auto-update`, Sat 03:00 (configurable `schedule`), persistent, 1h randomized delay. The user **lingers** (users.nix) so this fires with no login session; a suspended machine still sleeps through it and catches up at wake
- **Flow:** `git pull --rebase --autostash` (keeps e.g. the journal diary's pending known-issues edits intact) → `nix flake update` → test build → **VM smoke-test gate** → Claude (haiku) changelog from `nix store diff-closures` → haiku-generated generation slug written to `generation-label` → commit and verified push (one rebase-and-retry; headless runs need the `github_automation_token` sops secret, else commit-locally + notify) → `nixos-rebuild switch` (autoApply, green gate only) → notification
- **Breadcrumbs:** every run stamps `~/.local/state/claudeos/last-update-attempt`; success stamps `last-update`, reverts stamp `last-update-revert`. The morning desk and daily brief report "last successful flake update: N days ago" from these, and the health check raises an alert past 14 days — a silently dead updater can no longer hide
- **VM smoke-test gate** (`vmTest`, on by default; `vmTestTimeout`, 300 s): builds `config.system.build.vm` and boots the fresh generation headless in a throwaway QEMU VM (KVM, 4 GiB, 2 cores, no GPU/graphics, `diskImage = null` so nothing is written). An in-VM service (`claudeos-vm-smoke`, Type=exec so `is-system-running --wait` doesn't deadlock on its own startup job) asserts multi-user.target active, `systemctl --failed` empty, and `display-manager.service` active (GDM's real unit name on NixOS — the literal `gdm.service` never exists, which kept the gate red from 2026-06-12 to 2026-07-07), prints `CLAUDEOS-SMOKE-PASS`/`-FAIL` plus per-failed-unit journal excerpts on the serial console, and powers off; the host script greps the captured console
- **vmVariant strips hardware-specific config:** disko fileSystems (`disko.enableConfig`), snapper configs + subvolume activation script, btrfs autoScrub, scx, thermald, fwupd, Plymouth — all via `lib.mkVMOverride`. sops secrets can't decrypt in the VM (host SSH key never leaves the host) but install via an activation script, which logs and continues rather than failing a unit
- **Gate outcomes:** green → commit, push, switch; **no usable `/dev/kvm`** (or `vmTest = false`) → gate skipped, degrades to build-only (commit + push, never switch); red → `flake.lock` reverted, notification with the failing unit list, VM journal excerpt echoed into the unit's own journal, exit 1 → `OnFailure=claude-heal@claudeos-auto-update` hands it to the self-heal agent
- **autoApply plumbing:** scoped passwordless `sudo /run/current-system/sw/bin/nixos-rebuild` for wheel (`security.sudo-rs.extraRules`, only when `autoApply`); the user is in the `kvm` group (users.nix) so the timer-driven user unit can reach `/dev/kvm`
- **On build failure:** Claude (sonnet) diagnoses, `flake.lock` is reverted, user notified

### modules/common/generation-label.nix

Claude-named generations. Reads the repo-root `generation-label` file (a short slug written by the fish `rebuild` function and the auto-update service, usually authored by haiku from the pending diff) into `system.nixos.tags` -- so the systemd-boot menu and `nixos-rebuild list-generations` read like a changelog instead of "Generation 213". The charset is sanitized to `[a-zA-Z0-9:_.-]` because `system.nixos.label` rejects anything else at eval time. The writer (`claude-name-generation`, claude-helpers.nix) accepts only slug-shaped model output (`[a-z0-9-]`, ≤40 chars) and otherwise falls back to a timestamp slug — CLI/API error text used to get charset-mangled into a "valid" label (`You-ve-hit-your-monthly-spend-limit----r`) instead of rejected.

### modules/common/self-heal.nix

The OS files its own fix PRs (`claude-os.selfHeal`, enabled by default).

- **Mechanism:** systemd user template `claude-heal@.service` attached via `OnFailure=` to opted-in units (option `claude-os.selfHeal.units`; defaults: `claudeos-auto-update`, `claudeos-journal-diary`)
- **On failure:** a headless Claude agent (sonnet) receives the unit's journal + systemctl state, investigates the owning module, and -- only if the failure is config-rooted -- fixes it on a `heal/*` branch, validates with a dry-run build, and opens a PR via `gh pr create`. Transient failures get a `SKIP: <reason>` and no edits
- **Safety:** never touches main (human merge is the approval gate), per-unit 6h cooldown, restricted allowed tools; never watches `claude-heal@` itself or `claudeos-health-check` (loop prevention); skips upfront (with a notification) when no GitHub credential is reachable — keyring in-session, `github_automation_token` sops secret headless — rather than spending an agent session that cannot open a PR
- **Follow-up:** the agent session id is saved so the fish `approve` function can resume it

---

## modules/desktop/ -- Desktop Environment

GNOME on Wayland, audio, fonts, and theming. Imported via `modules/desktop/default.nix` which pulls in: `gnome.nix`, `audio.nix`, `fonts.nix`, `theme.nix`.

### modules/desktop/gnome.nix

GNOME desktop at the system level. Chosen June 2026 over Niri: familiar, best app integration (portals, file pickers, drag-and-drop, Chrome extension native messaging all first-class). Compositor experiments (Hyprland, etc.) can return later as specialisations.

**Display manager + desktop:**
- `services.displayManager.gdm.enable = true` (GDM, Wayland by default)
- `services.desktopManager.gnome.enable = true`

**Trimmed default apps** (`environment.gnome.excludePackages`): `gnome-tour`, `epiphany` (browser → Chrome), `geary` (mail → web), `gnome-music`, `totem`

**Services:**
- `services.openssh.settings.X11Forwarding = false` (`lib.mkDefault`)

**Session variables:**
- `NIXOS_OZONE_WL = "1"` (Electron apps use native Wayland)

**System packages:**
- `gnome-tweaks`, `wl-clipboard`, `zenity` (dialog prompts for `claude-ask-desktop`), `gnome-screenshot` (CLI capture for the screenshot scripts)
- Custom inline derivations: `tab-new-symbolic` SVG icon (for Ghostty's libadwaita tab bar, removed from adwaita-icon-theme in GNOME 46+), `folder-development` SVG icon (for ~/Projects)

**Hidden desktop entries** (via `hideDesktopEntries`):
`com.google.Chrome`, `vim`, `gvim`, `htop`, `micro`, `xterm`, `uxterm`, `nixos-manual`, `nm-applet`, `nm-connection-editor`, `org.freedesktop.Xwayland`

### modules/desktop/audio.nix

PipeWire audio and Bluetooth.

- **PulseAudio:** explicitly disabled
- **rtkit:** enabled (real-time scheduling for audio)
- **PipeWire:** enabled with `alsa.enable`, `pulse.enable`, `wireplumber.enable`
- **Bluetooth:** enabled, `powerOnBoot = false`, experimental features on, `Source,Sink,Media,Socket` enabled
- Audio managed through GNOME's own controls and `wpctl`; `pavucontrol`/`helvum` suggested via `nix shell` for advanced use

### modules/desktop/fonts.nix

Font packages and fontconfig. References `lib/theme.nix` for font names.

**Font packages:**
- `inter` (primary UI font)
- `noto-fonts`, `noto-fonts-cjk-sans`, `noto-fonts-color-emoji`
- `liberation_ttf`, `dejavu_fonts`
- `nerd-fonts.jetbrains-mono`, `nerd-fonts.fira-code`, `nerd-fonts.symbols-only`

**Fontconfig defaults:**
- Sans-serif: Inter, Noto Sans, DejaVu Sans
- Serif: Noto Serif, DejaVu Serif
- Monospace: JetBrains Mono, Symbols Nerd Font, Fira Code, DejaVu Sans Mono
- Emoji: Noto Color Emoji

**Rendering:** RGB subpixel, slight hinting (no autohint), antialiasing enabled. Custom `localConf` to prioritize Symbols Nerd Font before Noto Color Emoji in monospace fallback chain.

### modules/desktop/theme.nix

Stylix theming, Qt, and XDG portals. References `lib/theme.nix` for font names.

**Stylix:**
- `enable = true`, `polarity = "dark"`
- Custom base16 color scheme (values extracted from live claude.ai CSS tokens):
  - Backgrounds: `base00` = `1f1e1d`, `base01` = `262624`, `base02` = `30302e`
  - Dim/secondary text: `base03` = `9c9a92`, `base04` = `c2c0b6`
  - Primary foreground: `base05` = `faf9f5`, `base06` = `faf9f5`, `base07` = `ffffff`
  - Accents: `base08` = `c6613f` (dark terracotta, errors), `base09` = `e6956b` (peach), `base0A` = `c9b87c` (sand), `base0B` = `8a9a6b` (olive), `base0C` = `2c84db` (blue, secondary accent), `base0D` = `d97757` (terracotta, primary accent), `base0E` = `a67a5b` (brown), `base0F` = `bd5d3a` (deep terracotta)
- Wallpaper: `assets/chicago.jpg`, scaling mode `fill`
- Cursor: Adwaita, size 20 (all three properties set so Stylix manages `home.pointerCursor`)
- Fonts: serif = Noto Serif, sansSerif = Inter, monospace = JetBrains Mono Nerd Font, emoji = Noto Color Emoji (packages declared inline)

**Qt:** enabled, platform theme forced to `gtk2`, style forced to `adwaita-dark`.

**XDG portals:** provided and configured by GNOME itself (`xdg-desktop-portal-gnome` + gtk fallback) -- no manual wiring.

---

## modules/apps/ -- Applications

User-facing applications. Imported via `modules/apps/default.nix` which pulls in: `terminals.nix`, `claude.nix`, `jasper.nix`, `mcp-system-health`, `claude-monitor`, `morning-desk.nix`. Default-enables `claude-os.claude`, `claude-os.jasper`, `claude-os.monitor` (+ `dailyBrief` + `journalDiary`), and `claude-os.morningDesk`.

**Direct installs** (in `default.nix`): `google-chrome`, `obsidian`

Communication apps (Slack, Discord, Teams) are deliberately NOT packaged -- they're fast-moving Electron wrappers around web apps (ring 2). They're installed as Chrome PWAs instead (`chrome://apps`), so they auto-update and add zero closure weight.

### modules/apps/terminals.nix

Terminal emulator configuration (system-level).

- Sets `TERMINAL = "ghostty"` session variable
- Ghostty itself is installed via home-manager (`home/ghostty.nix`), not as a system package
- No custom `.desktop` file -- home-manager provides `com.mitchellh.ghostty.desktop`

### modules/apps/claude.nix

Claude Code CLI and Claude Desktop.

**nix-ld** (for dynamic binary compatibility):
- `programs.nix-ld.enable = true`
- Libraries: `stdenv.cc.cc.lib`, `glibc`, `openssl`, `zlib`, `curl`, `libz`, `icu`

**SSL compatibility:** symlinks `/etc/ssl/cert.pem` to the NixOS CA bundle.

**System packages:** `socat` (sandbox dependency)

**Claude Code CLI auto-installer:** systemd user service `claude-code-installer` that runs on first login if `~/.local/bin/claude` does not exist. Executes `curl -fsSL https://claude.ai/install.sh | bash`.

**Claude Desktop:** Installed via home-manager using the `claude-desktop-linux` flake input (follows main nixpkgs again). The flake extracts the macOS DMG, patches the Electron app for Linux, and wraps with nixpkgs electron — no insecure electron version needed.

### modules/apps/jasper.nix

Jasper, the personal-companion **lane** (`claude-os.jasper`, enabled by default). Formerly a standalone Rust daemon; now a ClaudeOS lane per `docs/PHILOSOPHY.md` "On Jasper specifically" — take the thinking, not the daemon. Built on `lib/claude-script.nix`, modeled on `morning-desk.nix`.

- **Poll (every 30 min during waking hours, configurable `schedule`):** a `oneshot` user service runs dumb collectors — weather (wttr.in) and calendar (gcalcli, if connected) — then a bash **significance gate** decides whether anything changed (hash of the day's stable weather + labelled agenda) or a morning/midday/evening heartbeat is due.
- **One call, one insight:** only when the gate fires does a single `claude -p` **sonnet** call (riding the Claude subscription — **no dedicated API key**) synthesize ONE warm, ownership-aware sentence ("Christen has soccer," never "you have soccer"). Written to `~/.cache/claudeos-monitor/jasper-insight.txt` (the monitor-cache file contract).
- **Face:** the `home/quickshell/Jasper.qml` singleton reads that file; the mood emoji joins the clock in the center island (`Island.qml`), and the sentence rides at the top of the calendar popup (`CalendarPopup.qml`) — one tap, one dropdown. One thing, never a feed.
- **Never touches `graphical-session.target`** — a plain `timers.target` oneshot, so the retired daemon's greeter-killing boot loop cannot recur.
- **Calendar bootstrap (one-time, interactive):** `gcalcli init` with the Google OAuth client from sops (`jasper_google_client_id`/`secret`); until then it runs weather-only and never invents events.

**Dependency:** `modules/common/secrets.nix` (Jasper's Google/home-address sops secrets). The `jasper_anthropic_api_key` secret is no longer consumed by this module.

### modules/apps/mcp-system-health/

System health MCP server for Claude Code.

- **Package:** `mcp-system-health` -- self-contained Python3 MCP stdio server (no external deps)
- **Protocol:** JSON-RPC 2.0 with Content-Length framing (MCP standard)
- **Tools exposed:** `disk_usage`, `failed_services`, `recent_errors`, `system_status`, `snapshot_list`, `network_status`, `nix_store_size`, `scrub_status`
- Registered as `system-health` MCP server in `home/claude-code.nix` (seeded `.mcp.json`)

### modules/apps/claude-monitor/

Proactive monitoring with Claude-authored notifications (`claude-os.monitor`, all tiers enabled by default).

- **Tier 1 -- health check:** pure-bash timer every 15 min (failed services, disk, memory, OOM kills, critical journal entries); $0 cost
- **Tier 2 -- notification:** `OnFailure` handler sends the alert context to Claude (haiku — high-frequency lane per the cost doctrine) for a human-readable notification with an "Open in Claude" action button; rate-limited to one Claude call per 30 min
- **Tier 3 -- daily brief** (`claude-os.monitor.dailyBrief`): 9 AM briefing (haiku) from system stats (uptime, failed units, disk, generations, flake age, repo state, diary findings), written to a cache file shown in the first terminal of the day
- **Tier 4 -- journal diary** (`claude-os.monitor.journalDiary`): nightly 4 AM haiku triage of deduplicated error-level journal lines against the persistent ledger `docs/known-issues.md` (edits ride the next rebuild auto-commit). Known-benign noise is silenced; new actionable findings land in `diary-actionable.txt` and feed the morning brief and morning desk. Saves its agent session id for `approve`

### modules/apps/morning-desk.nix

Overnight-built HTML morning dashboard (`claude-os.morningDesk`, enabled by default).

- **Build (05:30, configurable `schedule`):** collectors gather date, weather (wttr.in), calendar (gcalcli, if connected), overnight diary findings, failed units, disk, and repo state; Claude (sonnet) synthesizes ONE self-contained, Stylix-themed HTML5 page at `~/Desk/today/index.html` -- attention-first hierarchy (single most important thing on top, never a feed). Honest plain-HTML fallback if Claude is unavailable
- **Show:** at first login of the day, auto-opens in `google-chrome-stable --app` mode (one-shot stamp per day; only opens a dashboard generated today)
- **Archive:** previous day's dashboard copied to `~/Desk/archive/<date>.html`
- **Calendar bootstrap (one-time, interactive):** `gcalcli init` with the Google OAuth client from sops (`jasper_google_client_id`/`secret`)
- DE-agnostic by design: the artifact is a file; the opener is a URL

---

## home/ -- Home Manager Modules

User-level configuration. Imported from `home/default.nix` which pulls in: `shell/`, `ghostty.nix`, `git.nix`, `vscode.nix`, `gnome.nix`, `claude-code.nix`, `claudeos-help.nix`, `zathura.nix`.

### home/default.nix

Root home-manager module.

- `home.stateVersion = "24.11"`
- `home.username` and `home.homeDirectory` set from the `user` argument
- **XDG user directories:** enabled with standard directories plus `PROJECTS = "/home/${user}/Projects"`
- Creates `~/Projects/.directory` with `Icon=folder-development`
- `EDITOR`/`VISUAL` = `code --wait` (session variables, so `git commit`/`sops` block until the editor closes)
- **Default applications (mimeApps):** PDFs → zathura, images → Loupe (`org.gnome.Loupe`, GNOME's GTK4/Rust viewer -- replaced imv, an unmaintained Niri-era leftover that rendered undecorated on Mutter), archives → File Roller, directories → Nautilus (GNOME Files)
- `programs.home-manager.enable = true`
- **Hidden desktop entries** (user-level): `yazi`, `code-url-handler`, `kvantummanager`, `qt5ct`, `qt6ct`

### home/git.nix

Git and delta configuration.

**Git identity:** `user.name = "Tom Cassady"`, `user.email = "heytcass@gmail.com"` (declaratively configured)

**Aliases:** `st`, `co`, `br`, `ci`, `last`, `unstage`, `amend`, `graph`

**Settings:**
- `init.defaultBranch = "main"`
- `pull.rebase = true`
- `push.default = "simple"`, `push.autoSetupRemote = true`
- `diff.algorithm = "histogram"`
- `merge.conflictstyle = "diff3"`
- `rebase.autoStash = true`
- `rerere.enabled = true`
- `fetch.prune = true`
- `core.autocrlf = "input"`
- GitHub credential helper comes from `programs.gh.gitCredentialHelper` (gh CLI is configured in `home/shell/cli-tools.nix`, not here)
- `color.ui = true`

**Git LFS:** enabled

**Delta:** enabled with git integration, `line-numbers` and `decorations` features, `side-by-side = false`. Colors managed by Stylix.

### home/ghostty.nix

Ghostty terminal emulator (user-level). References `lib/theme.nix` for font names.

**Font:** forced font-family list overriding Stylix order: JetBrains Mono Nerd Font, Symbols Nerd Font, Noto Sans Symbols 2, Noto Color Emoji. Size 11.

**Settings:**
- Cursor: block, no blink
- Window padding: 8px each axis
- Window decoration: native GTK (`window-decoration = true`, `gtk-titlebar = true`)
- `linux-cgroup = "always"`
- Shell integration: Fish with `cursor,sudo,title` features
- Scrollback: 10000 lines
- `copy-on-select = true`, `mouse-hide-while-typing = true`
- `window-save-state = "always"`, `window-inherit-working-directory = true`, `window-inherit-font-size = true`
- `quit-after-last-window-closed = true`, `confirm-close-surface = false`

Colors are managed by Stylix (not hardcoded).

### home/vscode.nix

VS Code with declarative settings and Marketplace-managed extensions.

**Extensions:** deliberately NOT declared (two-ring design) -- Nix installs the VSCode binary, the Marketplace owns extensions, so in-app installs/updates don't fight home-manager. Suggested baseline: `anthropic.claude-code`, `jnoortheen.nix-ide`, `mkhl.direnv`, `yzhang.markdown-all-in-one`, `davidanson.vscode-markdownlint`, `redhat.vscode-yaml`

**Activation scripts:** stale `.backup` files are cleaned before linking; `settings.json`/`keybindings.json` store symlinks are replaced with writable copies so VSCode can persist runtime changes

**Editor settings:**
- Font ligatures on, format on save, minimap off
- Rulers at 80 and 120
- Whitespace rendering on selection
- Auto-save on focus change, trim trailing whitespace, insert final newline

**Nix integration:** nixd language server (`nix.serverPath = "nixd"`) with `nixfmt` as formatter; `nix.serverSettings.nixd.options.nixos.expr` evaluates the real flake (`nixosConfigurations.gti.options`), so completion/hover covers actual NixOS and home-manager options, not just syntax

**Other:**
- Default terminal profile: Fish
- `direnv.restart.automatic = true`
- Git: auto-fetch, no confirm sync, smart commit
- Telemetry off
- YAML schema for GitHub workflows
- Keybinding: `Ctrl+Shift+T` for new terminal
- Theme/fonts managed by Stylix

### home/gnome.nix

GNOME user configuration via dconf. Ports the Claude keybindings that lived in the old Niri config; everything else (idle, lock, displays, clipboard) is GNOME's own machinery.

**dconf settings:**
- Input sources: Colemak everywhere (`xkb us+colemak`; console keymap lives in `modules/common/locale.nix`)
- Interface: `color-scheme = "prefer-dark"`, battery percentage shown
- Idle + lock policy: blank at 5 min (`idle-delay = 300`), lock immediately on blank (`lock-enabled`, `lock-delay = 0`)

**Custom keybindings** (media-keys custom0-3):
- `Super+C` = `claude-quick` (Claude Code in Ghostty)
- `Super+A` = `claude-ask-desktop` (zenity prompt → notification)
- `Super+Shift+A` = `claude-screenshot` (gnome-screenshot → haiku analysis → notification)
- `Super+Ctrl+A` = `claude-screenshot-interactive` (screenshot → sonnet analysis in a terminal)

The scripts themselves are defined in `modules/common/system.nix`.

### home/claude-code.nix

Claude Code configuration, two-ring style: Nix SEEDS the config once, then the live files are mutable.

- **Seed-once activation:** `~/.claude/settings.json` and `~/.claude/.mcp.json` are copied from Nix-built seeds only if they don't exist -- Claude Code, `/config`, and MCP experimentation own the live files afterwards. To re-seed: delete the file and rebuild
- **Seeded settings:** statusline, globally-enabled plugins (github, learning-output-style, telegram), permissions, env
- **Seeded MCP servers:** `nixos` (mcp-nixos via `nix run`), `system-health` (`mcp-system-health` binary)
- **Statusline:** installed as a stable `claude-statusline` command on PATH (so the seeded settings never point at a GC-able store path); reads the Stylix palette for a themed status bar showing directory, git info, model, context usage, and cost estimate

### home/shell/default.nix

Shell module index. Imports: `fish.nix`, `cli-tools.nix`, `starship.nix`.

### home/shell/fish.nix

Fish shell configuration.

**Aliases:**
- `cat` = `bat --style=auto`, `man` = `batman`
- Navigation: `..`, `...`
- NixOS: `zc` (jump to config), `rebuild-test` (= `nh os test`), `flake-check`

**Abbreviations:** `gs`, `gd`, `gl`, `gp`, `gco`, `gci`, `gca`, `gaa`, `gcm`, `nfmt`, `ndev`, `nbuild`, `nrun`, `nshell`, `nrepl`, `nupdate`, `sctl`, `jctl`

**Functions:**
- Utility: `mkcd`, `extract` (delegates to ouch), `gcam`, `findbig`, `starship_transient_prompt_func`
- Claude-powered: `ask`, `fix`, `explain` (all haiku)
- `rebuild`: haiku writes a generation slug from the pending diff into `generation-label` (becomes the boot-menu label via `system.nixos.tags`) → snapper pre snapshots on root + home named "pre: <slug>" → `nh os switch` → post snapshots → Claude-generated conventional commit + push (`--no-commit` to skip)
- `approve`: resumes the last background agent session (self-heal, journal diary, morning desk save their session ids to `~/.local/state/claudeos/last-agent-session`) and authorizes its proposed action with full context
- `today`: opens `~/Desk/today/index.html` in Chrome app mode; `today --refresh` rebuilds the dashboard first

**Plugins:**
- `fzf.fish` (v10.3, PatrickF1)
- `puffer-fish` (nickeb96, text expansion)

**Interactive init:**
- Disables greeting
- Adds `~/.local/bin` to PATH (for Claude Code CLI)
- Exports `UNIFI_API_KEY` from `/run/secrets/unifi_api_key` (when present, for the UniFi MCP server). The GitHub token is deliberately NOT exported globally -- use the `with-github-token` wrapper (`home/shell/cli-tools.nix`) to materialize it per-process
- Shows the daily brief on first shell in a terminal (tracked via `CLAUDEOS_BRIEF_SHOWN` env var) -- deliberately the only first-shell output; the macchina system fetch was dropped per the proactivity doctrine (no spec-sheet feed above the brief)

`EDITOR` and `VISUAL` are set to `code --wait` in `home/default.nix` (session variables, so `git commit`/`sops` block until the editor closes).

### home/shell/starship.nix

Starship prompt with Fish integration.

**Format:** two-line prompt -- context on top line, input character below.

**Modules shown:** `username`, `hostname`, `directory`, `git_branch`, `git_status`, `nix_shell`, `cmd_duration`, `line_break`, `character`

**Styling:**
- Character: orange `❯` on success, red on error
- Directory: white, truncated to 3 segments / repo root
- Git branch: orange with ` ` symbol
- Git status: red (staged shown in green)
- Nix shell: cyan with ` ` symbol
- Command duration: bright-black, shown for commands > 2 seconds
- Username: yellow (shown only when non-default or SSH)
- Hostname: yellow (SSH only)

**Disabled language modules:** nodejs, python, rust, golang, java, ruby, php

### home/shell/cli-tools.nix

Modern CLI tool replacements.

**Packages (direct install):** `ripgrep`, `fd`, `jq`, `btop`, `ouch`, `bun`, and `uutils-coreutils-noprefix` at `lib.hiPrio` -- the two-ring pattern applied to coreutils: system scripts keep GNU coreutils, the interactive user PATH gets the Rust uutils

**`with-github-token` wrapper:** inline `writeShellScriptBin` that runs `GITHUB_PERSONAL_ACCESS_TOKEN="$(gh auth token)" exec "$@"` -- materializes the GitHub token only in the consuming process instead of exporting it into every shell; gh's keyring stays the single source of truth. Usage: `with-github-token <command...>`

**Configured programs:**
- **eza:** icons auto, git integration, group directories first, show header
- **zoxide:** Fish integration enabled
- **bat:** style `numbers,changes,header`, pager `less -FR`, extras: `batdiff`, `batman`, `batgrep`, `batwatch`
- **fzf:** Fish integration disabled (handled by `fzf.fish` plugin), uses `fd` for file/directory search, `bat` for file preview, `eza --tree` for directory preview
- **atuin:** Fish integration enabled, local-only by decision (`auto_sync = false`, sync deliberately not used), compact style, fuzzy search, global filter, preview enabled, inline height 20
- **yazi:** Fish integration enabled, hidden files off, natural sort, directories first
- **carapace:** multi-shell completion engine, Fish integration enabled
- **gh:** GitHub CLI -- SSH git protocol, `gitCredentialHelper.enable = true` (sole home of `programs.gh`; `home/git.nix` defers to it)
- **lazygit:** TUI git client
- **direnv:** enabled with `nix-direnv`

---

## hosts/ -- Per-Host Configuration

The `transporter` host (Dell Latitude 7280) serves as the testbed for the ClaudeOS return.

### hosts/gti/default.nix

Dell XPS 13 9370 (production). Imports `hardware-configuration.nix`.

- Pins the disko disk device to `/dev/nvme0n1` (NVMe SSD) -- required, since `modules/common/disko.nix` deliberately sets no default

### hosts/gti/hardware-configuration.nix

Generated by `nixos-generate-config`.

- initrd modules: `xhci_pci`, `nvme`, `usb_storage`, `sd_mod`, `rtsx_pci_sdmmc`
- Kernel modules: `kvm-intel`
- Intel microcode: enabled when redistributable firmware is on
- Platform: `x86_64-linux`

---

## Cross-Module Dependencies

```
flake.nix
  +-- lib/mkSystem.nix          (builds each host)
  |     +-- modules/common/     (foundation for all hosts)
  |     +-- modules/desktop/    (GNOME, audio, fonts, Stylix)
  |     +-- modules/apps/       (applications, Claude, Jasper, monitor, morning desk)
  |     +-- home/               (home-manager user config)
  +-- hosts/<hostname>/         (per-host hardware + overrides)
```

Notable dependency chains:
- `modules/apps/jasper.nix` reads secrets from `modules/common/secrets.nix` (sops)
- `modules/apps/claude.nix` uses `inputs.claude-desktop-linux`
- `home/gnome.nix` binds the Claude desktop scripts defined in `modules/common/system.nix`
- `home/shell/fish.nix` relies on tools configured in `home/shell/cli-tools.nix` (eza, bat, batman, zoxide) and on `nh` (`modules/common/nix.nix`), snapper (`modules/common/snapshots.nix`), and `generation-label` (`modules/common/generation-label.nix`) in the `rebuild` function
- `lib/theme.nix` is imported as pure data by `modules/desktop/fonts.nix`, `modules/desktop/theme.nix`, and `home/ghostty.nix`
- `home/claude-code.nix` seeds Claude Code settings; the statusline ships as the stable `claude-statusline` command
- `modules/apps/mcp-system-health/` registered in the seeded `.mcp.json` (`home/claude-code.nix`)
- `modules/common/self-heal.nix` and `modules/apps/claude-monitor/` save agent session ids consumed by the fish `approve` function
- `modules/apps/claude-monitor/` (Tier 4) writes `diary-actionable.txt`, consumed by both the daily brief and `modules/apps/morning-desk.nix`

---

*Last updated: 2026-06-12*
