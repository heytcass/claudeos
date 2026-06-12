# ClaudeOS

NixOS configuration optimized for Claude Code workflow.

## Quick Start

**For Claude agents:** Read [`CLAUDE.md`](CLAUDE.md) first.

**For humans:**
1. Clone repo: `git clone <repo-url> ~/.config/claudeos`
2. Enter dev shell: `nix develop`
3. Validate: `nix flake check`
4. Apply: `sudo nixos-rebuild switch --flake ~/.config/claudeos#$(hostname)`

## Machines

- **gti** - Dell XPS 13 9370 (production) - Deployed

## Features

- Flakes-based configuration with mkSystem factory pattern
- Modular architecture for easy maintenance
- home-manager integration for user config
- Hardware-optimized with nixos-hardware profiles
- Stylix theming with Claude-inspired color scheme
- Validation tools (nixfmt, statix, deadnix, nil)
- Documentation optimized for Claude agents and subagents
- Modern CLI tools (eza, bat, zoxide, atuin, yazi, fzf)
- Automated garbage collection and nix store optimization

## Stack

- **OS:** NixOS unstable
- **Desktop:** Niri (tiling compositor) + Noctalia shell + Wayland
- **Audio:** PipeWire with ALSA and PulseAudio compatibility
- **Shell:** Fish + Starship prompt + modern CLI tools
- **Terminal:** Ghostty
- **Fonts:** Inter (UI), JetBrains Mono Nerd Font (terminal/code)
- **Theme:** Stylix base16 with Claude brand colors
- **Claude:** Claude Code CLI + Claude Desktop (claude-for-linux)

## Documentation

- [CLAUDE.md](CLAUDE.md) - Main entry point for Claude agents (auto-loaded)
- [INSTALL.md](INSTALL.md) - Fresh NixOS installation guide
- [docs/WORKFLOW.md](docs/WORKFLOW.md) - Development workflow
- [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) - Deployment procedures
- [docs/MODULES.md](docs/MODULES.md) - Module documentation
- [docs/HARDWARE.md](docs/HARDWARE.md) - Hardware configs and optimizations
- [docs/SECRETS.md](docs/SECRETS.md) - Secrets management
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Common issues
- [docs/IMPLEMENTATION_STATUS.md](docs/IMPLEMENTATION_STATUS.md) - Current state
- [docs/THEME.md](docs/THEME.md) - Theme system
- [docs/DISKO.md](docs/DISKO.md) - Disk partitioning

**Subagents:** (in `.claude/agents/`)
- validator, builder, deployer, doc-generator, module-creator

## Current Status

Gti (Dell XPS 13 9370) is the primary machine (currently running Ubuntu pending the ClaudeOS reinstall). Transporter (Dell Latitude 7280) is defined as a testbed host to prove the integration story before gti is reinstalled.

**Future Enhancements:**
- NixOS impermanence for stateless system
- Binary cache setup for faster builds

## Contributing

This is a personal NixOS configuration. Feel free to fork and make it yours!

## License

MIT
