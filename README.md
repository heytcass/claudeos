# ClaudeOS

NixOS configuration optimized for Claude Code workflow.

## Quick Start

**For Claude agents:** Read [`docs/CLAUDE.md`](docs/CLAUDE.md) first.

**For humans:**

1. **Prerequisites:** NixOS installed on target machine (transporter or gti)
2. **Clone repo:** `git clone <repo-url> /home/tom/projects/claudeos`
3. **Enter dev shell:** `cd claudeos && nix develop`
4. **Validate:** `nix flake check`
5. **Deploy:** See [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md)

## Machines

- **transporter** - Dell Latitude 7280 (test machine)
- **gti** - Dell XPS 13 9370 (production)

## Features

- **Flakes-based** configuration with mkSystem factory pattern
- **Modular architecture** for easy maintenance
- **home-manager** integration for user configuration
- **sops-nix** for secrets management
- **Hardware-optimized** with nixos-hardware profiles
- **Development environment** with validation tools
- **Documentation optimized** for Claude agents

## Documentation

All docs in [`docs/`](docs/) directory:
- [CLAUDE.md](docs/CLAUDE.md) - Start here for agents
- [WORKFLOW.md](docs/WORKFLOW.md) - Development workflow
- [DEPLOYMENT.md](docs/DEPLOYMENT.md) - Deployment guide
- [MODULES.md](docs/MODULES.md) - Module documentation
- [IMPLEMENTATION_STATUS.md](docs/IMPLEMENTATION_STATUS.md) - Progress tracking

## Stack

- NixOS unstable
- GNOME + Wayland
- Pipewire audio
- Fish shell + modern CLI tools
- Claude Code + Claude Desktop + Claude in Chrome

## License

MIT (or specify your preferred license)
