# ClaudeOS

NixOS configuration optimized for Claude Code workflow.

## Quick Start

**For Claude agents:** Read [`CLAUDE.md`](CLAUDE.md) first, and [`docs/PHILOSOPHY.md`](docs/PHILOSOPHY.md) before any design decision — it is the canonical statement of what ClaudeOS is and why.

**For humans:**
1. Clone repo: `git clone <repo-url> ~/.config/claudeos`
2. Validate: `nix flake check`
3. Apply: `rebuild` (or `sudo nixos-rebuild switch --flake ~/.config/claudeos#$(hostname)`)

## Machines

- **gti** - Dell XPS 13 9370 (primary, currently running Ubuntu pending reinstall)
- **transporter** - Dell Latitude 7280 (testbed)

## Features

- Flakes-based configuration with mkSystem factory pattern
- Modular architecture for easy maintenance
- home-manager integration for user config
- Hardware-optimized with nixos-hardware profiles
- Stylix theming with Claude-inspired color scheme
- Validation tools (nixfmt, statix, deadnix, nixd)
- Documentation optimized for Claude agents and subagents
- Modern CLI tools (eza, bat, zoxide, atuin, yazi, fzf) with uutils coreutils on the user PATH
- nh-driven rebuilds (`nh os switch` with nom build graph, nvd closure diffs, declarative GC)
- `, foo` runs anything from nixpkgs without installing (comma + nix-index-database)
- Claude-named generations: every rebuild gets a haiku-written slug in the boot menu and matching snapper pre/post snapshots
- Self-maintaining layer: failed services spawn a Claude agent that opens fix PRs (`heal/*` branches), a nightly journal diary triages errors against a known-issues ledger, and a morning desk dashboard is built overnight
- Oxidized ring: sudo-rs, uutils-coreutils, scx_lavd BPF scheduler, dbus-broker, envfs

## Stack

- **OS:** NixOS unstable
- **Desktop:** GNOME on Wayland (GDM) — compositor experiments may return as specialisations
- **Audio:** PipeWire with ALSA and PulseAudio compatibility
- **Shell:** Fish + Starship prompt + modern CLI tools
- **Terminal:** Ghostty
- **Fonts:** Inter (UI), JetBrains Mono Nerd Font (terminal/code)
- **Theme:** Stylix base16 with Claude brand colors
- **Claude:** Claude Code CLI + Claude Desktop (claude-desktop-linux)

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

Gti (Dell XPS 13 9370) is the primary machine (currently running Ubuntu pending the ClaudeOS reinstall). Transporter (Dell Latitude 7280) is defined as a testbed host to prove the integration story before gti is reinstalled. The desktop is GNOME on Wayland — the earlier Niri + Noctalia stack was retired in June 2026 for better app integration (portals, file pickers, drag-and-drop).

**Future Enhancements:**
- NixOS impermanence for stateless system
- Binary cache setup for faster builds
- Compositor experiments (Hyprland, etc.) as specialisations

## Contributing

This is a personal NixOS configuration. Feel free to fork and make it yours!

## License

MIT
