# Module Documentation

Complete reference for all ClaudeOS NixOS configuration modules, generated from source.

## Architecture Overview

ClaudeOS is a multi-host NixOS flake. The entry point (`flake.nix`) defines two hosts -- `transporter` and `gti` -- both built via `lib/mkSystem.nix`. Every host automatically receives:

- **NixOS modules:** `modules/common/`, `modules/desktop/`, `modules/apps/`
- **home-manager** (as a NixOS module, not standalone): imports `home/default.nix`
- **Flake inputs:** home-manager, sops-nix, disko, stylix, niri, noctalia (loaded as NixOS modules)
- **Per-host hardware module** from nixos-hardware

The formatter is `nixfmt` (set in `flake.nix`).

### Flake Inputs

| Input | Source | Purpose |
|-------|--------|---------|
| nixpkgs | nixos-unstable | Package set and NixOS modules |
| home-manager | nix-community | User-level configuration |
| nixos-hardware | nixos | Hardware-specific quirks |
| sops-nix | Mic92 | Declarative secrets management |
| disko | nix-community | Declarative disk partitioning |
| stylix | danth | Unified theming (base16) |
| claude-for-linux | heytcass | Claude Desktop Electron app |
| jasper | heytcass | Jasper AI companion daemon |
| niri | sodiboo | Niri scrollable tiling compositor (flake) |
| noctalia | noctalia-dev | Noctalia Shell (bar, notifications, OSD, wallpaper) |

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

Used in both `modules/desktop/niri-system.nix` (system-level) and `home/default.nix` (user-level).

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

Core system configuration shared by all hosts. Imported via `modules/common/default.nix` which pulls in: `boot.nix`, `disko.nix`, `nix.nix`, `users.nix`, `networking.nix`, `locale.nix`, `system.nix`, `secrets.nix`, `snapshots.nix`.

### modules/common/boot.nix

Boot loader and kernel configuration.

- **Bootloader:** systemd-boot (UEFI), `canTouchEfiVariables = true`
- **Generations:** limited to 5 (`configurationLimit = 5`)
- **Plymouth:** enabled by default (`lib.mkDefault true`) with Claude logo (`assets/claude-logo.png`), animated spinning
- **Silent boot:** kernel params `quiet` and `splash`
- **Kernel:** latest (`linuxPackages_latest`, via `lib.mkDefault`)

### modules/common/disko.nix

Declarative disk layout via disko.

- **EFI partition:** 512MB vfat, mounted at `/boot`
- **Root partition:** remainder of disk, btrfs with subvolumes:
  - `@` mounted at `/`
  - `@home` mounted at `/home`
  - `@nix` mounted at `/nix`
  - `@log` mounted at `/var/log`
- **Mount options:** `noatime`, `compress=zstd:3`, `ssd`, `discard=async`, `space_cache=v2`
- **Default device:** `/dev/sda` (overridden to `/dev/nvme0n1` on gti)
- `disko.enableConfig` defaults to `true`

### modules/common/nix.nix

Nix daemon and nixpkgs configuration.

- **Experimental features:** `nix-command`, `flakes`
- **XDG base directories:** enabled (`use-xdg-base-directories = true`)
- **Store optimization:** `auto-optimise-store = true`
- **Dirty warning:** suppressed (`warn-dirty = false`)
- **Trusted users:** `root`, `@wheel`
- **Substituters:** `cache.nixos.org`, `nix-community.cachix.org` (with corresponding public keys)
- **Garbage collection:** weekly, deletes older than 30 days
- **Unfree packages:** allowed (`allowUnfree = true`)
- **State version:** `"24.11"`

### modules/common/users.nix

User account and shell setup.

- **User:** `tom` (normal user)
- **Groups:** `wheel`, `networkmanager`, `video`, `audio`
- **Shell:** Fish (`pkgs.fish`)
- **SSH keys:** one ed25519 key authorized (`tom@ubuntu-dev`)
- **Fish:** enabled system-wide (`programs.fish.enable = true`)
- **Sudo:** wheel group requires password by default (`lib.mkDefault true`)

### modules/common/networking.nix

Network, DNS, firewall, and SSH.

- **NetworkManager:** enabled
- **systemd-resolved:** enabled with `DNSSEC = "allow-downgrade"`, `DNSOverTLS = "no"`, fallback DNS `1.1.1.1` and `9.9.9.9`
- **Boot optimization:** `NetworkManager-wait-online` disabled
- **Firewall:** enabled, no ports opened by default
- **SSH server:** enabled, `PasswordAuthentication = false`, `PermitRootLogin = "no"`

### modules/common/locale.nix

Timezone, locale, and keyboard.

- **Timezone:** `America/New_York` (via `lib.mkDefault`)
- **Locale:** `en_US.UTF-8` for all `LC_*` categories
- **Console:** font `Lat2-Terminus16`, keymap `colemak`
- **Xkb:** layout `us`, variant `colemak`

### modules/common/system.nix

System packages, hardware, and kernel tuning.

**Packages:**
- Basic: `vim`, `micro`, `wget`, `curl`, `gh`, `htop`, `tree`, `file`, `unzip`, `zip`, `pciutils`, `usbutils`, `libnotify`
- Network: `dig`, `traceroute`
- Nix dev: `nixfmt`, `statix`, `deadnix`, `nil`
- Scripts: `claude-quick` launcher script (opens Claude Code in Ghostty)

**System configuration:**
- Creates `/bin/bash` symlink (activation script, for third-party scripts)
- `hardware.enableRedistributableFirmware = true`
- `services.fwupd.enable = true` (firmware updates)
- `services.thermald.enable = true` (Intel thermal management, `lib.mkDefault`)
- `zramSwap.enable = true` (compressed in-memory swap)
- `systemd.oomd` enabled on root, user, and system slices
- `boot.tmp.useTmpfs = true` (tmpfs for /tmp)
- `boot.kernel.sysctl."kernel.sysrq" = 1` (magic SysRq keys)
- `services.btrfs.autoScrub` enabled on `/`

### modules/common/secrets.nix

Declarative secrets via sops-nix.

- **Sops file:** `secrets/secrets.yaml`
- **Age key:** `/home/tom/.config/sops/age/keys.txt`
- **Managed secrets:**
  - `jasper_anthropic_api_key` -- owner `tom`, mode `0400`
  - `atuin_key` -- owner `tom`, mode `0400`

### modules/common/snapshots.nix

Snapper btrfs snapshot management.

- **Snapper:** enabled with hourly snapshot interval, daily cleanup, persistent timer
- **Root config:** SUBVOLUME `/`, timeline snapshots (hourly x 10, daily x 7, weekly x 2)
- **Home config:** SUBVOLUME `/home`, same retention, `ALLOW_USERS` includes the system user (no sudo needed)

---

## modules/desktop/ -- Desktop Environment

Niri compositor + Noctalia Shell, audio, fonts, and theming. Imported via `modules/desktop/default.nix` which pulls in: `niri-system.nix`, `audio.nix`, `fonts.nix`, `theme.nix`.

### modules/desktop/niri-system.nix

Niri compositor and greeter at the system level.

**Compositor:**
- `programs.niri.enable = true` (niri-flake handles package and session registration)

**Greeter:**
- `services.greetd` with `tuigreet --time --remember --remember-session --cmd niri-session`

**Services:**
- `services.gvfs.enable = true` (virtual filesystems: Trash, network shares)
- `services.openssh.settings.X11Forwarding = false`

**Session variables:**
- `GDK_BACKEND = "wayland,x11"`, `QT_QPA_PLATFORM = "wayland;xcb"`, `NIXOS_OZONE_WL = "1"` (Electron Wayland)

**System packages:**
- Wayland utilities: `wl-clipboard`, `cliphist`, `fuzzel`, `brightnessctl`, `grim`, `slurp`, `satty`, `thunar`, `xarchiver`
- Icon theme: `adwaita-icon-theme`
- Custom inline derivations: `tab-new-symbolic` SVG icon (for Ghostty libadwaita tab bar), `folder-development` SVG icon (for ~/Projects)

**Hidden desktop entries** (via `hideDesktopEntries`):
`com.google.Chrome`, `vim`, `gvim`, `htop`, `micro`, `xterm`, `uxterm`, `nixos-manual`, `nm-applet`, `nm-connection-editor`, `org.freedesktop.Xwayland`, `xdg-desktop-portal-gtk`, `geoclue-where-am-i`

### modules/desktop/audio.nix

PipeWire audio and Bluetooth.

- **PulseAudio:** explicitly disabled
- **rtkit:** enabled (real-time scheduling for audio)
- **PipeWire:** enabled with `alsa.enable`, `pulse.enable`, `wireplumber.enable`
- **Bluetooth:** enabled, `powerOnBoot = false`, experimental features on, `Source,Sink,Media,Socket` enabled
- Audio managed through Noctalia Shell and `wpctl`; `pavucontrol`/`helvum` suggested via `nix shell` for advanced use

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
- Custom base16 color scheme (Claude-inspired warm palette):
  - Backgrounds: `base00` = `1f1e1d`, `base01` = `262624`, `base02` = `30302e`
  - Dim/secondary text: `base03` = `9c9a92`, `base04` = `c2c0b6`
  - Primary foreground: `base05` = `faf9f5`, `base06` = `faf9f5`, `base07` = `ffffff`
  - Accents: `base08` = `c6613f` (terracotta), `base09` = `d97757` (orange), `base0A` = `c9b87c` (sand), `base0B` = `8a9a6b` (olive), `base0C` = `6b9e8a` (sage), `base0D` = `2c84db` (blue), `base0E` = `a67a5b` (brown), `base0F` = `d97757` (terracotta)
- Wallpaper: `assets/claude.png`, scaling mode `fill`
- Fonts: serif = Noto Serif, sansSerif = Inter, monospace = JetBrains Mono, emoji = Noto Color Emoji (packages declared inline)

**Qt:** enabled, platform theme forced to `gtk2`, style forced to `adwaita-dark`.

**XDG portals:** enabled with `xdg-desktop-portal-gtk` (niri-flake auto-adds `xdg-desktop-portal-gnome`), default set to `gtk`.

---

## modules/apps/ -- Applications

User-facing applications. Imported via `modules/apps/default.nix` which pulls in: `terminals.nix`, `claude.nix`, `jasper.nix`, `mcp-system-health`.

**Direct installs** (in `default.nix`): `google-chrome`, `slack`, `discord`, `obsidian`

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

**Insecure packages:** permits `electron-37.10.3` (required by Claude Desktop)

**Claude Code CLI auto-installer:** systemd user service `claude-code-installer` that runs on first login if `~/.local/bin/claude` does not exist. Executes `curl -fsSL https://claude.ai/install.sh | bash`.

**Claude Desktop:** Installed via home-manager using the `claude-for-linux` flake input. The app.asar from the flake is wrapped with the system's `electron_37` in an FHS environment (with bubblewrap, nodejs, glibc, openssl, coreutils, bash, git, curl). A custom XDG desktop entry is created with name "Claude", categories Development/Utility, and `x-scheme-handler/claude` MIME type.

### modules/apps/jasper.nix

Jasper AI companion daemon.

**System packages:** `jasperPkgs.daemon` (from `inputs.jasper`). Noctalia bar plugin is a follow-up task.

**Systemd user service** (`jasper-companion`):
- Starts after `graphical-session.target`
- Reads `ANTHROPIC_API_KEY` from sops secret (`jasper_anthropic_api_key`) at runtime
- Restarts on failure (5 second delay)

**Dependency:** `modules/common/secrets.nix` (provides the sops secret)

### modules/apps/mcp-system-health/

System health MCP server for Claude Code.

- **Package:** `mcp-system-health` -- self-contained Python3 MCP stdio server (no external deps)
- **Protocol:** JSON-RPC 2.0 with Content-Length framing (MCP standard)
- **Tools exposed:** `disk_usage`, `failed_services`, `recent_errors`, `system_status`, `snapshot_list`, `network_status`, `nix_store_size`, `scrub_status`
- Registered as `system-health` MCP server in `home/claude-code.nix`

---

## home/ -- Home Manager Modules

User-level configuration. Imported from `home/default.nix` which pulls in: `shell/`, `ghostty.nix`, `git.nix`, `vscode.nix`, `niri.nix`, `macchina.nix`, `claude-code.nix`.

### home/default.nix

Root home-manager module.

- `home.stateVersion = "24.11"`
- `home.username` and `home.homeDirectory` set from the `user` argument
- **XDG user directories:** enabled with standard directories plus `PROJECTS = "/home/${user}/Projects"`
- Creates `~/Projects/.directory` with `Icon=folder-development`
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
- `credential.helper = "!gh auth git-credential"` (GitHub CLI)
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

VS Code with declarative extensions and settings.

**Extensions:** `jnoortheen.nix-ide`, `mkhl.direnv`, `yzhang.markdown-all-in-one`, `davidanson.vscode-markdownlint`, `redhat.vscode-yaml`

**Editor settings:**
- Font ligatures on, format on save, minimap off
- Rulers at 80 and 120
- Whitespace rendering on selection
- Auto-save on focus change, trim trailing whitespace, insert final newline

**Nix integration:** nil language server with `nixfmt` as formatter

**Other:**
- Default terminal profile: Fish
- `direnv.restart.automatic = true`
- Git: auto-fetch, no confirm sync, smart commit
- Telemetry off
- YAML schema for GitHub workflows
- Keybinding: `Ctrl+Shift+T` for new terminal
- Theme/fonts managed by Stylix

### home/niri.nix

Niri compositor settings, Noctalia Shell, Stylix targets, and GTK theming. References `lib/theme.nix` for icon name.

**Imports:** `niri.homeModules.niri` (portal/keyring), `niri.homeModules.stylix` (auto-derives border colors), `noctalia.homeModules.default`

**Stylix targets:** `gtk`, `ghostty`, `vscode`, `fzf`, `bat`, `lazygit`, `niri` all enabled.

**GTK:**
- Icon theme: Adwaita (`adwaita-icon-theme` package)
- GTK3/GTK4: `gtk-application-prefer-dark-theme = 1`
- Force-overwrites Stylix-managed `gtk-3.0/gtk.css` and `gtk-4.0/gtk.css`

**dconf:** sets `org/gnome/desktop/interface` to `color-scheme = "prefer-dark"` and `icon-theme = "Adwaita"`

**Niri settings** (`programs.niri.settings`):
- Input: Colemak layout (`xkb.variant = "colemak"`)
- Layout: 8px gaps, 2px border (Stylix-derived colors), preset widths 1/3 + 1/2 + 2/3, transparent background
- Window rules: `claude-quick` opens floating, all windows get 12px corner radius
- Layer rules: `noctalia-wallpaper` and `noctalia-overview` use `place-within-backdrop`
- Debug: `honor-xdg-activation-with-invalid-serial` (for Noctalia notifications)
- Spawn at startup: `noctalia-shell`, `wl-paste --watch cliphist store`

**Keybindings** (via `config.lib.niri.actions`):
- `Mod+Return` = Ghostty, `Mod+C` = claude-quick, `Ctrl+Alt+Space` = Claude Desktop
- `Mod+D` = fuzzel, `Mod+Q` = close, `Mod+F` = fullscreen, `Mod+Space` = cycle widths
- `Mod+Left/Right` = focus columns, `Mod+Up/Down` = focus workspaces
- `Mod+Shift+Left/Right/Up/Down` = move windows/columns
- `Mod+1..5` = workspace switch, `Mod+Shift+1..5` = move to workspace
- `Mod+Tab` = overview, `Mod+L` = Noctalia lock screen, `Print` = screenshot
- `Mod+Shift+C` = clipboard history (fuzzel + cliphist)
- Media keys for volume/brightness via wpctl/brightnessctl

**Noctalia Shell:** enabled with systemd service, default configuration (refine via built-in settings UI)

### home/macchina.nix

System fetch tool with custom ASCII art and Stylix-derived colors.

- Installs `macchina` package
- Theme name: `claudeos`
- Displayed fields: Host, Distribution, DesktopEnvironment, Shell, Uptime, Memory, Packages
- Key color: `base09` (orange), separator color: `base03` (dim), ASCII art color: `base08` (terracotta)
- Custom ASCII art in `~/.config/macchina/ascii/clawd.txt` (Claude asterisk glyph)
- Rounded box border, bars with `"●"` glyph, palette hidden

### home/claude-code.nix

Declarative Claude Code configuration via home-manager.

- Generates `~/.claude/settings.json` from Nix (statusline, plugins, env, hooks)
- Generates `~/.claude/.mcp.json` (MCP server registrations: nixos, system-health)
- **Statusline script:** reads Stylix palette for themed status bar showing directory, git info, model, context usage, and cost estimate
- **Notification hook:** reads JSON from stdin, sends desktop notification via `notify-send`
- **Plugins:** frontend-design, github, feature-dev, superpowers, pr-review-toolkit, agent-sdk-dev, plugin-dev, learning-output-style, and more
- `force = true` on both files (Nix is authoritative over runtime edits)

### home/shell/default.nix

Shell module index. Imports: `fish.nix`, `cli-tools.nix`, `starship.nix`.

### home/shell/fish.nix

Fish shell configuration.

**Aliases:**
- `cat` = `bat --style=auto`, `man` = `batman`
- Git: `gs`, `gd`, `gl`, `gp`
- Navigation: `..`, `...`
- NixOS: `zc` (jump to config), `rebuild` (function with snapper pre/post snapshots), `rebuild-test`, `flake-check`

**Abbreviations:** `gco`, `gci`, `gca`, `gaa`, `gcm`, `nfmt`, `ndev`, `nbuild`, `nrun`, `sctl`, `jctl`

**Functions:** `mkcd`, `extract` (archive extractor), `gcam`, `findbig`

**Plugins:**
- `fzf.fish` (v10.3, PatrickF1)
- `puffer-fish` (nickeb96, text expansion)

**Interactive init:**
- Disables greeting
- Adds `~/.local/bin` to PATH (for Claude Code CLI)
- `EDITOR` and `VISUAL` set to `code`
- Runs `macchina` on first shell in terminal (tracked via `MACCHINA_SHOWN` env var)

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

**Packages (direct install):** `ripgrep`, `fd`, `jq`

**Configured programs:**
- **eza:** icons auto, git integration, group directories first, show header
- **zoxide:** Fish integration enabled
- **bat:** style `numbers,changes,header`, pager `less -FR`, extras: `batdiff`, `batman`, `batgrep`, `batwatch`
- **fzf:** Fish integration disabled (handled by `fzf.fish` plugin), uses `fd` for file/directory search, `bat` for file preview, `eza --tree` for directory preview
- **atuin:** Fish integration enabled, sync disabled, compact style, fuzzy search, global filter, preview enabled, inline height 20
- **yazi:** Fish integration enabled, hidden files off, natural sort, directories first
- **direnv:** enabled with `nix-direnv`

---

## hosts/ -- Per-Host Configuration

### hosts/transporter/default.nix

Dell Latitude 7280 (test system). Imports only `hardware-configuration.nix`. No overrides -- uses all defaults (disk device `/dev/sda`, etc.).

### hosts/transporter/hardware-configuration.nix

Generated by `nixos-generate-config --no-filesystems` (filesystems managed by disko).

- initrd modules: `xhci_pci`, `ahci`, `usb_storage`, `sd_mod`, `rtsx_pci_sdmmc`
- Kernel modules: `kvm-intel`
- Intel microcode: enabled when redistributable firmware is on
- Platform: `x86_64-linux`

### hosts/gti/default.nix

Dell XPS 13 9370 (production). Imports `hardware-configuration.nix`.

- Overrides disko device to `/dev/nvme0n1` (NVMe SSD)

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
  |     +-- modules/desktop/    (Niri, Noctalia, audio, fonts, Stylix)
  |     +-- modules/apps/       (applications, Claude, Jasper)
  |     +-- home/               (home-manager user config)
  +-- hosts/<hostname>/         (per-host hardware + overrides)
```

Notable dependency chains:
- `modules/apps/jasper.nix` reads secrets from `modules/common/secrets.nix` (sops)
- `modules/apps/claude.nix` uses `inputs.claude-for-linux` and `inputs.nixpkgs` (electron)
- `home/niri.nix` imports niri-flake and noctalia home-manager modules, enables Stylix targets for GTK, Ghostty, VS Code, and Niri
- `home/shell/fish.nix` relies on tools configured in `home/shell/cli-tools.nix` (eza, bat, batman, zoxide)
- `lib/theme.nix` is imported as pure data by `modules/desktop/fonts.nix`, `modules/desktop/theme.nix`, `home/ghostty.nix`, and `home/niri.nix`
- `home/claude-code.nix` generates Claude Code settings referencing store-path scripts (statusline, notify)
- `modules/apps/mcp-system-health/` registered in `home/claude-code.nix` MCP config
- `modules/common/snapshots.nix` enables snapper used by `home/shell/fish.nix` rebuild function

---

*Last updated: 2026-02-16*
