# Module Documentation

Complete documentation for all ClaudeOS modules.

## Overview

ClaudeOS uses a modular architecture where functionality is split into focused, composable modules. This document describes each module's purpose, configuration options, dependencies, and usage patterns.

## Module Organization

```
modules/
├── common/         # Foundation (boot, nix, users, networking, locale, system, disko)
├── desktop/        # Desktop environment (cosmic-system, audio, fonts, theme)
└── apps/           # Applications (terminals, browsers, communication, claude)

home/
├── shell/          # Shell config (fish, cli-tools, starship)
├── ghostty.nix     # Ghostty terminal user config
├── git.nix         # Git user config
├── vscode.nix      # VSCode user config
├── cosmic.nix      # COSMIC/GTK user config (dconf, icon theme)
└── theme.nix       # Stylix Home Manager targets
```

---

## common/ - Foundation Modules

Core system configuration loaded for all machines.

### modules/common/boot.nix

**Purpose:** Boot loader configuration using systemd-boot

**Configuration:**
- systemd-boot UEFI bootloader
- Keeps last 5 generations to save space
- Latest kernel for best hardware support
- Silent boot with "quiet splash" parameters
- Plymouth disabled by default (can be enabled per-machine)

**Dependencies:** None

**Location:** modules/common/boot.nix:1

**Usage:** Automatically loaded for all machines via common/default.nix

---

### modules/common/nix.nix

**Purpose:** Nix package manager configuration

**Configuration:**
- Enables flakes and nix-command experimental features
- Auto-optimizes nix store
- Trusted users: root and wheel group
- Binary cache: NixOS and nix-community cachix
- Weekly automatic garbage collection (30-day retention)
- Allows unfree packages system-wide
- System state version: 24.11

**Dependencies:** None

**Location:** modules/common/nix.nix:1

**Options:**
```nix
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;
  nix.gc.automatic = true;
  nixpkgs.config.allowUnfree = true;
}
```

---

### modules/common/users.nix

**Purpose:** User account configuration

**Configuration:**
- Defines "tom" user account
- Groups: wheel (sudo), networkmanager, video, audio, docker
- Default shell: Fish
- Sudo for wheel group (password required by default)
- Fish enabled system-wide

**Dependencies:**
- Fish shell package

**Location:** modules/common/users.nix:1

**Usage:** Customization options:
```nix
# To enable passwordless sudo:
security.sudo.wheelNeedsPassword = false;

# To add SSH keys:
users.users.tom.openssh.authorizedKeys.keys = [ "ssh-ed25519 ..." ];
```

---

### modules/common/networking.nix

**Purpose:** Network and SSH configuration

**Configuration:**
- NetworkManager for network management
- Firewall enabled (empty port lists by default)
- SSH server enabled
- Password authentication enabled (disable after key setup)
- Root login disabled
- Disables NetworkManager-wait-online for faster boot

**Dependencies:** None

**Location:** modules/common/networking.nix:1

**Options:**
```nix
{
  networking.firewall.allowedTCPPorts = [ ]; # Add ports as needed
  services.openssh.settings.PasswordAuthentication = true; # Disable after key setup
}
```

---

### modules/common/locale.nix

**Purpose:** Timezone, language, and keyboard configuration

**Configuration:**
- Timezone: America/New_York (configurable per-machine)
- Locale: en_US.UTF-8
- Console keymap: Colemak
- X11/Wayland keyboard: US Colemak variant

**Dependencies:** None

**Location:** modules/common/locale.nix:1

**Customization:**
```nix
# To change timezone per-machine:
time.timeZone = lib.mkForce "America/Los_Angeles";
```

---

### modules/common/system.nix

**Purpose:** Essential system packages and firmware

**Configuration:**
- Basic utilities: vim, micro, wget, curl, git, gh, htop, tree
- File utilities: file, unzip, zip
- Hardware tools: pciutils, usbutils
- Network tools: dig, nmap, traceroute
- Build essentials: gcc, gnumake
- NTFS filesystem support
- Firmware updates (fwupd)
- Thermald for Intel CPU thermal management

**Dependencies:** None

**Location:** modules/common/system.nix:1

---

## desktop/ - Desktop Environment

COSMIC desktop with Wayland, audio, fonts, and theming.

### modules/desktop/cosmic-system.nix

**Purpose:** COSMIC desktop environment (system-level)

**Configuration:**
- COSMIC display manager (cosmic-greeter)
- COSMIC Desktop Environment
- Wayland session
- Excludes xterm (pulled in by X dependencies)
- GVfs for virtual filesystems
- GNOME Keyring for credential storage

**Dependencies:**
- Wayland support

**Location:** modules/desktop/cosmic-system.nix:1

**Integration:**
- Works with modules/apps/terminals.nix (Ghostty)
- Works with home/cosmic.nix (GTK app theming)
- Works with home/theme.nix (Stylix theming)

---

### modules/desktop/audio.nix

**Purpose:** Pipewire audio server with full compatibility

**Configuration:**
- Pipewire (replaces PulseAudio and JACK)
- ALSA support with 32-bit compatibility
- PulseAudio compatibility layer
- JACK compatibility for pro audio
- Wireplumber session manager
- Bluetooth audio with experimental codecs
- Bluetooth disabled on boot (battery saving)
- Real-time scheduling (rtkit)
- Audio tools: pavucontrol, helvum

**Dependencies:**
- Bluetooth hardware support

**Location:** modules/desktop/audio.nix:1

**Options:**
```nix
{
  hardware.bluetooth.powerOnBoot = false; # Can enable for auto-start
  hardware.bluetooth.settings.General.Experimental = true; # Better codecs
}
```

---

### modules/desktop/fonts.nix

**Purpose:** Font configuration matching Claude AI aesthetics

**Configuration:**
- Primary UI font: Inter (matches Claude AI interface)
- System fonts: Noto Sans, Noto Serif, Liberation TTF, DejaVu
- CJK support: Noto Sans CJK
- Emoji: Noto Color Emoji
- Programming fonts: JetBrains Mono Nerd Font, Fira Code Nerd Font
- Font rendering: RGB subpixel, slight hinting, antialiasing

**Dependencies:** None

**Location:** modules/desktop/fonts.nix:1

**Font Priorities:**
- Sans-serif: Inter → Noto Sans → DejaVu Sans
- Monospace: JetBrains Mono → Fira Code → DejaVu Sans Mono

---

### modules/desktop/theme.nix

**Purpose:** GTK, Qt, and XDG portal theming

**Configuration:**
- Adwaita theme (clean, minimal, professional)
- Qt applications use GTK theme for consistency
- XDG portals for desktop integration
- Dconf enabled for settings

**Dependencies:**
- COSMIC desktop

**Location:** modules/desktop/theme.nix:1

---

## apps/ - Applications

User-facing applications.

### modules/apps/terminals.nix

**Purpose:** Terminal emulator installation

**Configuration:**
- Installs Ghostty terminal
- Sets Ghostty as default terminal (TERMINAL env var)
- Desktop file for terminal:// URL handling
- xterm hidden (see desktop/cosmic-system.nix)

**Dependencies:**
- Ghostty package
- User config: home/ghostty.nix

**Location:** modules/apps/terminals.nix:1

**Integration:** User configuration in home/ghostty.nix provides GTK/libadwaita integration for native decorations

---

### modules/apps/browsers.nix

**Purpose:** Web browser installation

**Configuration:**
- Google Chrome installation
- Requires allowUnfree (configured in common/nix.nix)
- Extensions and sync configured manually

**Dependencies:**
- Unfree packages enabled

**Location:** modules/apps/browsers.nix:1

**Manual Steps:** Configure Chrome extensions and sign in to Google account

---

### modules/apps/communication.nix

**Purpose:** Communication applications

**Configuration:**
- Slack installation
- Discord installation
- Both are unfree packages
- Authentication configured manually

**Dependencies:**
- Unfree packages enabled

**Location:** modules/apps/communication.nix:1

**Manual Steps:** Login to Slack and Discord accounts

---

### modules/apps/claude.nix

**Purpose:** Claude Code CLI support with nix-ld

**Configuration:**
- Enables nix-ld for dynamic library compatibility
- Provides libraries: glibc, openssl, zlib, curl, icu
- PATH configuration in home/shell/fish.nix
- Installation via official Anthropic installer

**Dependencies:**
- nix-ld
- Fish shell (for PATH)

**Location:** modules/apps/claude.nix:1

**Installation Steps:**
1. Deploy configuration with nix-ld
2. Run: `curl -fsSL https://claude.ai/install.sh | bash`
3. Claude Code installs to ~/.local/bin/claude
4. Auto-updates work seamlessly

**Other Claude Interfaces:**
- **Chrome Extension:** Manual install from Chrome Web Store
- **VSCode Extension:** Manual install from VSCode marketplace
- **Claude Desktop:** Not included (no official Linux support)

---

## home/ - Home Manager User Configuration

User-specific configuration managed by home-manager.

### home/ghostty.nix

**Purpose:** Ghostty terminal user configuration

**Configuration:**
- Font: JetBrains Mono Nerd Font (size 11)
- Claude-inspired color scheme (dark background #1a1d23)
- GTK/libadwaita integration for native decorations
- No tab bar (clean look)
- Fish shell integration (cursor, sudo, title)
- Scrollback: 10,000 lines
- Copy on select
- Window state persistence

**Dependencies:**
- Ghostty system installation (apps/terminals.nix)
- JetBrains Mono Nerd Font (desktop/fonts.nix)

**Location:** home/ghostty.nix:1

**Key Features:**
- Native COSMIC/GTK window decorations
- Shell integration with Fish
- Auto-copy on selection
- Window position/size persistence

---

### home/git.nix

**Purpose:** Git user configuration

**Configuration:**
- User identity left unconfigured (manual setup)
- Helpful aliases (st, co, br, ci, graph)
- Default branch: main
- Pull strategy: rebase
- Push: auto-setup remote
- Diff algorithm: histogram
- Merge conflict style: diff3
- Auto-stash on rebase
- Editor: micro
- Git LFS enabled
- Delta integration for better diffs

**Dependencies:**
- Delta package

**Location:** home/git.nix:1

**Manual Setup Required:**
```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

---

### home/vscode.nix

**Purpose:** VSCode user configuration

**Configuration:**
- Extensions: Nix IDE, direnv, nix-env-selector, Markdown, YAML
- Font: JetBrains Mono with ligatures (size 13)
- Theme: Default Dark+
- Terminal: Fish integration
- Nix language server: nil with nixpkgs-fmt
- Format on save
- Minimap disabled
- Auto-save on focus change
- Telemetry disabled

**Dependencies:**
- VSCode system installation (installed via system packages)
- JetBrains Mono font (desktop/fonts.nix)
- nil language server
- nixpkgs-fmt formatter

**Location:** home/vscode.nix:1

**Manual Steps:**
- Install Claude extension from marketplace

---

### home/cosmic.nix

**Purpose:** GTK preferences for apps running under COSMIC

**Configuration:**
- Adwaita icon theme
- Dark mode for GTK3/GTK4 applications
- dconf settings for GTK app compatibility
- Ensures consistent theming for GTK apps under COSMIC

**Dependencies:**
- COSMIC desktop environment
- dconf support

**Location:** home/cosmic.nix:1

**Integration:**
- Complements desktop/theme.nix (system-level theming)
- Provides user-level GTK preferences

---

### home/theme.nix

**Purpose:** Stylix Home Manager targets

**Configuration:**
- Enables Stylix for GTK
- Enables Stylix for Ghostty
- Enables Stylix for VSCode
- Provides consistent theming across applications

**Dependencies:**
- Stylix module
- GTK, Ghostty, VSCode installations

**Location:** home/theme.nix:1

**Integration:**
- Works with desktop/theme.nix (system-level Stylix)
- Applies theming to user applications

---

### home/shell/fish.nix

**Purpose:** Fish shell configuration

**Configuration:**
- Modern CLI aliases (eza, bat integration)
- Git shortcuts
- NixOS-specific aliases (rebuild, flake-check)
- Abbreviations for quick expansion
- Custom functions: mkcd, extract, gcam, findbig
- Fish plugins: fzf.fish, z (zoxide), puffer-fish
- Environment variables
- Colored man pages
- ~/.local/bin added to PATH (for Claude Code)

**Dependencies:**
- eza, bat, zoxide (home/shell/cli-tools.nix)
- Fish system installation (common/users.nix)

**Location:** home/shell/fish.nix:1

**Key Features:**
- Seamless integration with modern CLI tools
- Git workflow shortcuts
- NixOS system management helpers
- Archive extraction utility

---

### home/shell/cli-tools.nix

**Purpose:** Modern CLI tool replacements

**Configuration:**
- **eza:** ls replacement with icons and git integration
- **zoxide:** Smart cd with frecency tracking
- **bat:** cat with syntax highlighting and paging
- **fzf:** Fuzzy finder with bat previews
- **atuin:** Shell history search (sync disabled)
- **yazi:** TUI file manager
- **ripgrep, fd:** Fast search tools
- **jq:** JSON processor
- **direnv:** Per-project environments

**Dependencies:**
- Fish shell (for integrations)

**Location:** home/shell/cli-tools.nix:1

**Integration:**
- All tools integrate with Fish shell
- fzf uses bat for file previews
- fzf uses eza for directory previews

---

### home/shell/starship.nix

**Purpose:** Cross-shell prompt configuration

**Configuration:**
- Clean, single-line format
- Shows: directory, git branch/status, nix-shell, exit code
- Username/hostname only when relevant (SSH, non-default user)
- Command duration for slow commands (>2s)
- Language version detection disabled (faster prompt)

**Dependencies:**
- Fish shell integration

**Location:** home/shell/starship.nix:1

**Prompt Components:**
- Directory (cyan, truncated to repo)
- Git branch (purple) and status (red)
- Nix shell indicator (blue)
- Character: green (❯) on success, red on error

---

## Module Dependencies

Visual dependency tree:

```
common/ (no dependencies)
  └─> desktop/ (depends on common)
       └─> apps/ (depends on desktop for COSMIC)
       └─> home/ (depends on apps)
            └─> home/shell/ (depends on CLI tools)
```

**Load Order:**
1. common/ - Foundation
2. desktop/ - Desktop environment
3. apps/ - Applications
4. home/ - User configuration
5. home/shell/ - Shell configuration

---

## Usage Patterns

### Adding a New Module

1. Create module file in appropriate category
2. Follow module template from .claude/agents/module-creator.md
3. Add import to category's default.nix
4. Run validation: `nix flake check`
5. Test build before deploying
6. Document in this file

### Per-Machine Overrides

```nix
# In hosts/<hostname>/default.nix
{
  # Override default timezone
  time.timeZone = lib.mkForce "America/Los_Angeles";

  # Add machine-specific packages
  environment.systemPackages = with pkgs; [
    machine-specific-tool
  ];
}
```

### Module Enable/Disable Pattern

Most modules are always enabled. To selectively disable:

```nix
# In module file
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.mymodule;
in {
  options.programs.mymodule = {
    enable = mkEnableOption "mymodule";
  };

  config = mkIf cfg.enable {
    # Configuration here
  };
}
```

---

## Best Practices

1. **Keep modules focused:** Each module should have one clear purpose
2. **Use mkDefault:** Allow per-machine overrides with `lib.mkDefault`
3. **Document options:** Add clear descriptions to all options
4. **Minimize dependencies:** Avoid circular dependencies between modules
5. **Test incrementally:** Validate after each module addition
6. **Follow conventions:** Use existing modules as templates

---

## Reference

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [NixOS Options Search](https://search.nixos.org/options)
- [Home Manager Options](https://nix-community.github.io/home-manager/options.html)

---

*Last updated: 2026-02-02*
