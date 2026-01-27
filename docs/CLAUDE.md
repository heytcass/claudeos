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
- **One module at a time** - Keep context focused
- **Use subagents** - validator, builder, deployer, doc-generator, module-creator

## Subagents (in .claude/agents/)
- `@validator-agent check all` - Before suggesting changes
- `@builder-agent build <hostname>` - Test builds
- `@deployer-agent deploy <hostname>` - Full deployment
- `@doc-generator-agent update` - Sync documentation
- `@module-creator-agent create <path>` - Scaffold modules

## Machines
| Host | Hardware | Purpose | Status |
|------|----------|---------|--------|
| transporter | Dell Latitude 7280 | Test | 🟡 Phase 1 in progress |
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
3. Validate: `nix flake check`
4. Commit and push to git
5. SSH to target machine
6. Pull changes and `sudo nixos-rebuild switch --flake .#<hostname>`

See [WORKFLOW.md](./WORKFLOW.md) for detailed steps.

## Current Phase: Phase 1 - Foundation

Creating core system files:
- ✅ Git repo initialized
- ✅ Directory structure created
- ✅ docs/CLAUDE.md created
- ⏳ Creating flake.nix with mkSystem pattern
- ⏳ Creating common modules
- ⏳ Creating host configurations

Next: Boot NixOS with SSH access on transporter
