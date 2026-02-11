# ClaudeOS - NixOS Configuration

This is a NixOS system configuration repo optimized for tight Claude integration throughout the OS. After any configuration changes, always run `nixos-rebuild build --flake .` (or equivalent) to verify the build succeeds before committing. Never commit untested NixOS changes.

## Environment

User runs NixOS with COSMIC desktop environment, Fish shell with Starship prompt. Do not assume bash/PS1 or GNOME/KDE defaults.

## NixOS Configuration

This is a multi-device NixOS flake. Changes may need to apply to multiple hosts. Always check which hosts are affected and ensure consistency (e.g., Intel microcode was only conditionally set on one device).

## CRITICAL: Ask Questions, Don't Assume

**ALWAYS use the `AskUserQuestion` tool whenever you need clarification.**

- ❌ **DO NOT make assumptions** about what the user wants
- ❌ **DO NOT guess** at implementation details or preferences
- ❌ **DO NOT assume** you know the user's intent
- ✅ **DO ask** for clarification at ANY point during development
- ✅ **DO use** the `AskUserQuestion` tool for ALL questions
- ✅ **DO stop and ask** if anything is unclear or ambiguous

**Examples of when to ask:**

- "Should I use approach A or B?"
- "Which module should this configuration go in?"
- "Do you want me to test this before committing?"
- "Should I update the documentation as well?"
- "Is this the behavior you expected?"

## Quick Reference

| Machine | IP | Purpose | Status |
|---------|-----|---------|--------|
| transporter | 10.0.10.205 | Test system (Dell Latitude 7280) | Deployed |
| gti | TBD | Production (Dell XPS 13 9370) | Ready for deployment |

**Stack:** NixOS unstable • COSMIC • Wayland • Pipewire • home-manager • sops-nix (future) • Stylix

## Workflow

All work is done directly on NixOS machines:

1. **Edit** configuration in `~/.config/claudeos`
2. **Validate** changes with `nix flake check`
3. **Apply** changes with `sudo nixos-rebuild switch --flake ~/.config/claudeos#$(hostname)`
4. **Sync** between machines with `git push` / `git pull`

## Debugging / NixOS

When diagnosing NixOS build issues, trace the actual dependency chain (e.g., `nix why-depends`, grep for the package in flake inputs and modules) rather than guessing the source. Do not add config options without verifying they exist in the relevant NixOS module.

## Documentation

All documentation is in the repository:

- [INSTALL.md](INSTALL.md) - Fresh NixOS installation
- [docs/WORKFLOW.md](docs/WORKFLOW.md) - Development workflow
- [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) - Deployment procedures
- [docs/MODULES.md](docs/MODULES.md) - Module documentation
- [docs/HARDWARE.md](docs/HARDWARE.md) - Hardware configs
- [docs/SECRETS.md](docs/SECRETS.md) - Secrets management (future)
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Common issues
- [docs/IMPLEMENTATION_STATUS.md](docs/IMPLEMENTATION_STATUS.md) - Current state
- [docs/THEME.md](docs/THEME.md) - Theme system
- [docs/DISKO.md](docs/DISKO.md) - Disk layout
