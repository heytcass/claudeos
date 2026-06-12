# ClaudeOS Status

**Last Updated:** 2026-06-11

## Current State

ClaudeOS is a fully operational NixOS configuration for personal machines.

### Deployed: gti (Dell XPS 13 9370)

Production machine — the only host in the flake. transporter (Dell Latitude 7280) was retired and removed from `flake.nix` and `hosts/`.

**What works:**
- Niri compositor + Noctalia shell on Wayland
- Pipewire audio with Bluetooth
- Ghostty terminal with Fish shell and Starship prompt
- Modern CLI tools (eza, bat, zoxide, atuin, yazi, fzf, ripgrep, fd)
- Chrome, Slack, Discord, VSCode
- Claude Code CLI (via nix-ld)
- Claude Desktop (via claude-desktop-linux)
- Stylix theming with Claude brand colors
- btrfs with zstd compression and subvolumes (snapper timeline + number cleanup)
- Automated garbage collection and store optimization
- Weekly auto-update service (git pull --rebase, flake update, test build, verified push)
- systemd-boot with 5 generations retained and the boot-entry editor disabled

## Module Summary

| Category | Modules | Purpose |
|----------|---------|---------|
| common/ | boot, disko, nix, users, networking, locale, system, secrets, snapshots, auto-update | Foundation |
| desktop/ | niri-system, audio, fonts, theme | Niri + Noctalia desktop |
| apps/ | terminals, claude, jasper, mcp-system-health, mcp-niri, claude-monitor | Applications + AI |
| home/ | shell (fish, cli-tools, starship), ghostty, git, vscode, niri, macchina, claude-code, claudeos-help | User config |

## Future Enhancements

- [x] Deploy to gti (production machine)
- [x] sops-nix for declarative secrets management
- [x] Automated btrfs snapshots before rebuilds (snapper with pre/post rebuild pairs)
- [x] Declarative Claude Code configuration (settings.json + .mcp.json from Nix)
- [x] System health MCP server for Claude Code diagnostics
- [x] Desktop keybindings for Claude Code (Mod+C) and Claude Desktop (Ctrl+Alt+Space)
- [ ] NixOS impermanence for stateless system
- [ ] Binary cache for faster builds
- [ ] Atuin sync (currently disabled; the `atuin_key` sops declaration was removed — re-declare in `modules/common/secrets.nix` when enabling)
- [ ] Declare `unifi_api_key` secret for the UniFi MCP server (`.mcp.json` reads it from the environment)
- [ ] TLP or auto-cpufreq for laptop power management

## Maintenance Log

### 2026-06-11
- Security/quality audit cleanup
  - Removed retired transporter host from flake (gti is now the sole host)
  - Disko: ESP grown to 1G; no default disk device (each host pins its own)
  - Boot: configurationLimit 5, systemd-boot editor disabled
  - Snapper: NUMBER_CLEANUP/NUMBER_LIMIT/EMPTY_PRE_POST_CLEANUP on root + home
  - Auto-update: git pull --rebase before update, verified push with rebase retry
  - Polkit: removed manage-unit-files from passwordless wheel rule
  - Removed undeclared atuin_key sops declaration; .mcp.json UniFi key now read from environment
  - Thunar via programs.thunar (+xfconf) with plugins; dropped services.xserver.xkb; LLMNR off; fstrim on
  - EDITOR/VISUAL = code --wait; programs.gh consolidated into home/shell/cli-tools.nix
  - imv colors from Stylix palette; swayidle explicit PATH + attrset events
  - Documentation synchronized with the above

### 2026-02-15
- Phase 4: Deep Claude Integration
  - Declarative Claude Code config (settings.json + .mcp.json from Nix)
  - Snapper btrfs snapshots with pre/post rebuild safety
  - System health MCP server (8 diagnostic tools)
  - COSMIC keybindings: Super+C (Claude Code), Ctrl+Alt+Space (Claude Desktop)
  - Desktop notifications via notify-send hooks

### 2026-02-14
- Hardened CLAUDE.md with theming conventions, workflow guardrails, and config location rules
- Centralised hardcoded destructive red into lib/theme.nix extended palette
- Updated documentation to reflect current state

### 2026-02-12
- Added SOPS/age runtime secret decryption for Jasper daemon
- Deployed gti (Dell XPS 13 9370) to production

### 2026-02-10
- Added macchina system fetch with custom ASCII art and Stylix-themed colors
- Redesigned Starship prompt to match Claude Code aesthetic
- Flake updates and breaking change fixes (stale patches)
- Config cleanup, Claude automation improvements

### 2026-02-02
- Major cleanup: removed dead code, consolidated documentation, updated for direct NixOS workflow

### 2026-01-30
- Migrated from GNOME to COSMIC desktop
- Replaced WezTerm with Ghostty
- Added Stylix theming with Claude brand colors
- Added Claude Desktop via claude-for-linux flake
- Post-migration cleanup and hardening

### 2026-01-27
- Initial deployment to transporter (Phases 1-4)
- Core system, desktop, applications, Claude Code CLI
- btrfs filesystem with subvolumes
