# Module Documentation

**Complete module documentation will be added in Phase 6.**

This file will document:
- All module responsibilities
- Module dependencies
- Configuration options
- Usage examples
- Integration points

## Module Categories

### common/
Foundation modules loaded for all machines.

**Implemented:**
- `boot.nix` - systemd-boot bootloader configuration modules/common/boot.nix:1
- `nix.nix` - Nix settings, flakes, GC modules/common/nix.nix:1
- `users.nix` - User accounts, fish shell modules/common/users.nix:1
- `networking.nix` - NetworkManager, SSH, firewall modules/common/networking.nix:1
- `locale.nix` - Timezone, internationalization modules/common/locale.nix:1
- `system.nix` - Base system packages modules/common/system.nix:1

### desktop/
Desktop environment modules.

**Phase 2 - To be implemented:**
- `gnome.nix` - GNOME desktop + Wayland
- `audio.nix` - Pipewire audio
- `fonts.nix` - System and programming fonts
- `theme.nix` - GTK, icons, cursors

### apps/
Application modules.

**Phase 3-4 - To be implemented:**
- `terminals.nix` - WezTerm
- `browsers.nix` - Chrome
- `communication.nix` - Slack, Discord
- `claude.nix` - Claude Code, Desktop, Chrome extension config

### development/
Development environment modules.

**Phase 3 - To be implemented:**
- `direnv.nix` - direnv + nix-direnv
- `git.nix` - Git system configuration
- `vscode.nix` - VSCode system configuration

### services/
System services.

**Phase 2+ - To be implemented as needed**

## home/
Home-manager user configuration.

**Phase 3 - To be implemented:**
- `shell/fish.nix` - Fish shell configuration
- `shell/cli-tools.nix` - Modern CLI tools (eza, zoxide, bat, atuin, yazi)
- `shell/starship.nix` - Starship prompt
- `git.nix` - Git user configuration
- `wezterm.nix` - WezTerm configuration
- `vscode.nix` - VSCode user configuration

---

_This file will be completed in Phase 6 with full documentation._
