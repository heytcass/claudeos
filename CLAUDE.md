# ClaudeOS - NixOS Configuration

This is a NixOS system configuration repo optimized for tight Claude integration throughout the OS. After any configuration changes, always run `nixos-rebuild build --flake .` (or equivalent) to verify the build succeeds before committing. Never commit untested NixOS changes.

## Environment

User runs NixOS with COSMIC desktop environment, Fish shell with Starship prompt. Do not assume bash/PS1 or GNOME/KDE defaults.

## NixOS Configuration

This is a multi-device NixOS flake. Changes may need to apply to multiple hosts. Always check which hosts are affected and ensure consistency (e.g., Intel microcode was only conditionally set on one device).

## CRITICAL: Ask Questions, Don't Assume

**Never assume — always use `AskUserQuestion` when anything is unclear.** Ask about: approach choices, which module to use, whether to test/commit/update docs, or if behavior matches expectations.

## Quick Reference

| Machine | IP | Purpose | Status |
|---------|-----|---------|--------|
| transporter | 10.0.10.205 | Test system (Dell Latitude 7280) | Deployed |
| gti | TBD | Production (Dell XPS 13 9370) | Ready for deployment |

**Stack:** NixOS unstable • COSMIC • Wayland • Pipewire • home-manager • sops-nix (future) • Stylix

## Architecture

```
flake.nix              # Entry point — defines transporter + gti hosts
lib/mkSystem.nix       # Host builder — wires common modules + home-manager
hosts/<hostname>/      # Per-host: default.nix (overrides) + hardware-configuration.nix
modules/common/        # Shared NixOS config: boot, networking, nix, users, locale, disko
modules/desktop/       # COSMIC, audio, fonts, Stylix theme
modules/apps/          # System packages: terminals, claude, jasper
home/                  # home-manager modules: shell, git, ghostty, vscode, cosmic-theme
lib/                   # Helpers: mkSystem, hideDesktopEntries, theme utilities
assets/                # Static files (wallpapers, etc.)
```

**Key inputs:** nixpkgs (unstable), home-manager, nixos-hardware, sops-nix, disko, stylix, claude-for-linux, jasper

home-manager runs as a NixOS module (not standalone) — configured in `lib/mkSystem.nix`.

## Workflow

All work is done directly on NixOS machines:

1. **Edit** configuration in `~/.config/claudeos`
2. **Validate** with `nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel --dry-run` (both hosts)
3. **Check** with `nix flake check`
4. **Format** with `nix fmt`
5. **Apply** with `sudo nixos-rebuild switch --flake ~/.config/claudeos#$(hostname)`
6. **Sync** between machines with `git push` / `git pull`

## Debugging / NixOS

When diagnosing NixOS build issues, trace the actual dependency chain (e.g., `nix why-depends`, grep for the package in flake inputs and modules) rather than guessing the source. Do not add config options without verifying they exist in the relevant NixOS module.

## Documentation

Documentation lives in `docs/` and `INSTALL.md` — check there for workflow, deployment, hardware, theme, and troubleshooting details.
