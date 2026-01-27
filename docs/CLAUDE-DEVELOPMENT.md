# ClaudeOS Configuration - Documentation Index

**START HERE** - All documentation is modular for Claude context optimization.

## Quick Navigation
- New to project? → [WORKFLOW.md](./WORKFLOW.md)
- Deploying? → [DEPLOYMENT.md](./DEPLOYMENT.md)
- Hardware issues? → [HARDWARE.md](./HARDWARE.md)
- Something broken? → [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)
- Understanding modules? → [MODULES.md](./MODULES.md)
- Managing secrets? → [SECRETS.md](./SECRETS.md)
- Track progress? → [IMPLEMENTATION_STATUS.md](./IMPLEMENTATION_STATUS.md)

## Critical Constraints
- **Ubuntu dev → NixOS deploy** - Never edit config on target machines
- **No global dev tools** - Use direnv for project-specific toolchains
- **Validate first** - Always `nix flake check` before suggesting changes
- **Stage before validate** - Git add new files before `nix flake check` (flakes require tracked files)
- **Test build before deploy** - Use `nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel --dry-run`
- **One module at a time** - Keep context focused
- **Use subagents** - validator, builder, deployer, doc-generator, module-creator

## Subagents (in .claude/agents/)
- `@validator-agent check all` - Before suggesting changes
- `@builder-agent build <hostname>` - Test builds
- `@deployer-agent deploy <hostname>` - Full deployment
- `@doc-generator-agent update` - Sync documentation
- `@module-creator-agent create <path>` - Scaffold modules

## Common Gotchas

### Recent Package Renames (NixOS 25.05+)
- `noto-fonts-emoji` → `noto-fonts-color-emoji`
- `nerdfonts.override { fonts = [...]; }` → `nerd-fonts.jetbrains-mono`, `nerd-fonts.fira-code`

### Deprecated Options (NixOS 25.05+)
- `sound.enable` - Removed (use Pipewire/ALSA directly)
- `services.xserver.desktopManager.gnome.enable` → `services.desktopManager.gnome.enable`
- `services.xserver.displayManager.gdm.*` → `services.displayManager.gdm.*`
- `hardware.pulseaudio` → `services.pulseaudio`

### Desktop Patterns
- Hide app from launcher: `environment.etc."xdg/applications/app.desktop".text = ''[Desktop Entry]\nHidden=true'';`
- Exclude GNOME apps: Add to `environment.gnome.excludePackages`

## Machines
| Host | Hardware | Purpose | Status |
|------|----------|---------|--------|
| transporter | Dell Latitude 7280 | Test | 🟢 Phase 2 complete |
| gti | Dell XPS 13 9370 | Production | ⚪ Not started |

## Architecture Overview

### Flake Entry Point
- `flake.nix` uses `mkSystem` factory pattern to eliminate boilerplate
- Each machine gets hardware-specific modules from nixos-hardware
- All machines share common base modules

### Module Categories
- **common/** - Boot, nix config, users, networking, locale, system packages
- **desktop/** - GNOME, audio (Pipewire), fonts, theme
- **apps/** - Terminals, browsers, communication tools, Claude tools
- **development/** - direnv, git, VSCode
- **services/** - System services

### Home Manager
- Integrated as NixOS module (not standalone)
- Manages: Fish shell, CLI tools (eza, zoxide, bat, atuin, yazi), Starship prompt, WezTerm, git, VSCode

### Secrets
- sops-nix with age encryption
- Secrets stored in `secrets/secrets.yaml` (encrypted)
- Setup in Phase 5

## Development Workflow Summary

1. Work on Ubuntu dev machine in `/home/tom/projects/claudeos`
2. Make changes to configuration
3. Stage files: `git add <files>` (required for flakes)
4. Validate: `nix flake check` and optionally `nix build ... --dry-run`
5. Commit and push to git
6. SSH to target machine (ssh tom@10.0.10.205 for transporter)
7. `cd ~/.config/claudeos && git pull`
8. `sudo nixos-rebuild switch --flake .#<hostname>`

See [WORKFLOW.md](./WORKFLOW.md) for detailed steps.

## Current Phase: Phase 3 - Applications & Shell

Status:
- ✅ Phase 1: Foundation (core system, SSH access)
- ✅ Phase 2: Desktop (GNOME 49.2, Wayland, Pipewire, Inter font)
- ⏳ Phase 3: Applications & Shell (in progress)
- ⏳ Phase 4: Claude Tools
- ⏳ Phase 5: Secrets & Production
- ⏳ Phase 6: Documentation & Polish

See [IMPLEMENTATION_STATUS.md](./IMPLEMENTATION_STATUS.md) for detailed progress.
