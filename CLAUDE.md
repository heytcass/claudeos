# ClaudeOS - NixOS Configuration

This is a NixOS system configuration repo optimized for tight Claude integration throughout the OS. After any configuration changes, always run `nixos-rebuild build --flake .` (or equivalent) to verify the build succeeds before committing. Never commit untested NixOS changes.

## Environment

User runs NixOS with COSMIC desktop environment, Fish shell with Starship prompt. Do not assume bash/PS1 or GNOME/KDE defaults.

## Theming & Styling

**Always use Stylix/base16 palette references — never hardcode hex color values.** The system uses a unified theming approach via Stylix (defined in `modules/desktop/theme.nix`). When a module needs colors, reference the base16 scheme through `config.lib.stylix.colors` or equivalent — do not paste raw `#rrggbb` values.

## NixOS Configuration

This is a multi-device NixOS flake. Changes may need to apply to multiple hosts. Always check which hosts are affected and ensure consistency (e.g., Intel microcode was only conditionally set on one device).

## CRITICAL: Ask Questions, Don't Assume

**Never assume — always use `AskUserQuestion` when anything is unclear.** Ask about: approach choices, which module to use, whether to test/commit/update docs, or if behavior matches expectations.

## Hosts

This is a multi-host flake. The SessionStart hook injects which machine you're on — always use `$(hostname)` in build/deploy commands. Available hosts are defined in `hosts/` and `flake.nix`.

**Stack:** NixOS unstable • COSMIC • Wayland • Pipewire • home-manager • sops-nix • Stylix

## Architecture

```
flake.nix              # Entry point — defines all hosts (see hosts/ directory)
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

1. **Stage** new files with `git add` — Nix flakes only see tracked files
2. **Edit** configuration in `~/.config/claudeos`
3. **Validate** with `nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel --dry-run` (both hosts)
4. **Check** with `nix flake check`
5. **Format** with `nix fmt`
6. **Apply** with `sudo nixos-rebuild switch --flake ~/.config/claudeos#$(hostname)`
7. **Push** with `git push` — remote rebuilds pull from the repo, so never skip this
8. **Sync** between machines with `git pull`

**Important:** Always modify files in `~/.config/claudeos/` — never edit upstream module files or flake input sources directly.

## Debugging / NixOS

When diagnosing NixOS build issues, trace the actual dependency chain (e.g., `nix why-depends`, grep for the package in flake inputs and modules) rather than guessing the source. Do not add config options without verifying they exist in the relevant NixOS module.

## Documentation

Documentation lives in `docs/` and `INSTALL.md` — check there for workflow, deployment, hardware, theme, and troubleshooting details.
