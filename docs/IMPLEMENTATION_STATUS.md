# ClaudeOS Status

**Last Updated:** 2026-02-02

## Current State

ClaudeOS is a fully operational NixOS configuration for personal machines.

### Deployed: transporter (Dell Latitude 7280)

Test machine, fully deployed and operational since 2026-01-27.

**What works:**
- COSMIC desktop on Wayland
- Pipewire audio with Bluetooth
- Ghostty terminal with Fish shell and Starship prompt
- Modern CLI tools (eza, bat, zoxide, atuin, yazi, fzf, ripgrep, fd)
- Chrome, Slack, Discord, VSCode
- Claude Code CLI (via nix-ld)
- Claude Desktop (via claude-for-linux)
- Stylix theming with Claude brand colors
- btrfs with zstd compression and subvolumes
- Automated garbage collection and store optimization
- systemd-boot with 5 generations retained

**Storage:** 238.5GB SSD, btrfs with ~30% compression savings

### Ready for deployment: gti (Dell XPS 13 9370)

Configuration exists and builds successfully. Awaiting physical installation.

## Module Summary

| Category | Modules | Purpose |
|----------|---------|---------|
| common/ | boot, nix, users, networking, locale, system, disko | Foundation |
| desktop/ | cosmic-system, audio, fonts, theme | COSMIC desktop |
| apps/ | terminals, browsers, communication, claude | Applications |
| home/ | shell (fish, cli-tools, starship), ghostty, git, vscode, cosmic, theme | User config |

## Future Enhancements

- [ ] Deploy to gti (production machine)
- [ ] sops-nix for declarative secrets management
- [ ] NixOS impermanence for stateless system
- [ ] Automated btrfs snapshots before rebuilds
- [ ] Binary cache for faster builds
- [ ] Atuin sync across machines (needs sops-nix for key)
- [ ] TLP or auto-cpufreq for laptop power management

## Maintenance Log

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
