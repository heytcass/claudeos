# ClaudeOS

NixOS configuration optimized for Claude Code workflow.

## Quick Start

**For Claude agents:** Read [`CLAUDE.md`](CLAUDE.md) first.

**For humans:**

**On Ubuntu (development):**
1. **Clone repo:** `git clone <repo-url> /home/tom/projects/claudeos`
2. **Enter dev shell:** `cd claudeos && nix develop`
3. **Validate:** `nix flake check`

**On NixOS (target machines):**
1. **Prerequisites:** NixOS installed on target machine
2. **Clone to user config:** `git clone <repo-url> ~/.config/claudeos`
3. **Deploy:** See [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) or [`INSTALL.md`](INSTALL.md)

## Machines

- **transporter** - Dell Latitude 7280 (test machine)
- **gti** - Dell XPS 13 9370 (production)

## Features

- **Flakes-based** configuration with mkSystem factory pattern
- **Modular architecture** for easy maintenance and customization
- **home-manager** integration for user-specific configuration
- **Hardware-optimized** with nixos-hardware profiles (Dell Latitude & XPS)
- **Development environment** with validation tools (nixpkgs-fmt, statix, deadnix, nil)
- **Documentation optimized** for Claude agents and subagents
- **Modern CLI tools** (eza, bat, zoxide, atuin, yazi, fzf)
- **Automated garbage collection** and nix store optimization

**Future Enhancements:**
- sops-nix for declarative secrets management (when needed)
- NixOS impermanence for stateless system
- Binary cache setup for faster builds

## Documentation

**For Claude Agents:**
- [CLAUDE.md](CLAUDE.md) - Main entry point (auto-loaded)
- [CLAUDE-DEVELOPMENT.md](docs/CLAUDE-DEVELOPMENT.md) - Building configuration on Ubuntu
- [CLAUDE-OPERATIONS.md](docs/CLAUDE-OPERATIONS.md) - Operating deployed NixOS systems

**For Humans:**
- [INSTALL.md](INSTALL.md) - Fresh NixOS installation guide
- [WORKFLOW.md](docs/WORKFLOW.md) - Development workflow
- [DEPLOYMENT.md](docs/DEPLOYMENT.md) - Deployment procedures

**Reference:**
- [MODULES.md](docs/MODULES.md) - Complete module documentation (21 modules)
- [HARDWARE.md](docs/HARDWARE.md) - Hardware configs, issues, and optimizations
- [SECRETS.md](docs/SECRETS.md) - Secrets management (future: sops-nix)
- [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [IMPLEMENTATION_STATUS.md](docs/IMPLEMENTATION_STATUS.md) - Project progress

**Subagents:** (in `.claude/agents/`)
- validator, builder, deployer, doc-generator, module-creator

## Stack

- **OS:** NixOS unstable (24.11)
- **Desktop:** GNOME 49 + Wayland (X11 fallback available)
- **Audio:** Pipewire 1.4 with ALSA, PulseAudio, and JACK compatibility
- **Shell:** Fish + Starship prompt + modern CLI tools
- **Terminal:** Ghostty with GTK/libadwaita (native GNOME integration)
- **Fonts:** Inter (UI), JetBrains Mono Nerd Font (terminal/code)
- **Claude:** Claude Code CLI + Claude in Chrome extension

## Project Status

**Current:** Phase 6 (Documentation & Polish) - In Progress

**Completed:**
- ✅ Phase 1: Foundation (Core system, btrfs, SSH)
- ✅ Phase 2: Desktop Environment (GNOME 49 + Wayland)
- ✅ Phase 3: Applications & Shell (Ghostty, Fish, modern CLI)
- ✅ Phase 4: Claude Tools (Claude Code CLI via nix-ld)

**Remaining:**
- Phase 5: Production Deployment (gti machine)
- Phase 6: Final documentation polish

See [IMPLEMENTATION_STATUS.md](docs/IMPLEMENTATION_STATUS.md) for detailed progress.

## Contributing

This is a personal NixOS configuration. Feel free to fork it and make it yours!

## License

MIT (or specify your preferred license)
