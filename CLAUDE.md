# ClaudeOS - NixOS Configuration

This is a NixOS system configuration repo optimized for tight Claude integration throughout the OS. After any configuration changes, always run `nixos-rebuild build --flake .` (or equivalent) to verify the build succeeds before committing. Never commit untested NixOS changes.

**Read `docs/PHILOSOPHY.md` before making design decisions.** It captures why ClaudeOS exists, the founding insight (the system is one git repo, so the OS can maintain itself via PRs), the two-ring rule, the proactivity doctrine, decided security trade-offs, and the cost doctrine. If a proposal changes one of its conclusions, update PHILOSOPHY.md in the same PR.

## Environment

User runs NixOS with Hyprland on Wayland + a bespoke Quickshell bar (chosen 2026-07; GNOME was removed entirely in the rip-out — docs/plans/2026-07-11-gnome-ripout-plan.md). Session must be launched via the "Hyprland (UWSM)" entry at the regreet greeter. Fish shell with Starship prompt. Do not assume bash/PS1.

## Theming & Styling

**Always use Stylix/base16 palette references — never hardcode hex color values.** The system uses a unified theming approach via Stylix (defined in `modules/desktop/theme.nix`). When a module needs colors, reference the base16 scheme through `config.lib.stylix.colors` or equivalent — do not paste raw `#rrggbb` values.

## NixOS Configuration

This is a multi-host flake (`gti` primary, `transporter` testbed). Check which hosts a change affects and keep shared settings in `modules/common/` (e.g., Intel microcode was once conditionally set on only one device).

## CRITICAL: Ask Questions, Don't Assume

**Never assume — always use `AskUserQuestion` when anything is unclear.** Ask about: approach choices, which module to use, whether to test/commit/update docs, or if behavior matches expectations.

## Hosts

Always use `$(hostname)` in build/deploy commands rather than hardcoding a host name. Available hosts are defined in `hosts/` and `flake.nix`: `gti` (Dell XPS 13 9370, primary) and `transporter` (Dell Latitude 7280, testbed).

**Stack:** NixOS unstable • Hyprland (Wayland) + Quickshell bar • greetd/regreet • Pipewire • home-manager • sops-nix • Stylix

## Architecture

```
flake.nix              # Entry point — defines all hosts (see hosts/ directory)
lib/mkSystem.nix       # Host builder — wires common modules + home-manager
hosts/<hostname>/      # Per-host: default.nix (overrides) + hardware-configuration.nix
modules/common/        # Shared NixOS config: boot, networking, nix, users, locale, disko
modules/desktop/       # Hyprland + greetd, audio, fonts, Stylix theme
modules/apps/          # System packages: terminals, claude, jasper
home/                  # home-manager modules: shell, git, ghostty, vscode, hyprland, quickshell/
lib/                   # Helpers: mkSystem, hideDesktopEntries, theme utilities
assets/                # Static files (wallpapers, etc.)
```

**Key inputs:** nixpkgs (unstable), home-manager, nixos-hardware, sops-nix, disko, stylix, claude-desktop-linux, nix-index-database, mcp-nixos

home-manager runs as a NixOS module (not standalone) — configured in `lib/mkSystem.nix`.

## Workflow

All work is done directly on NixOS machines:

1. **Stage** new files with `git add` — Nix flakes only see tracked files
2. **Edit** configuration in `~/.config/claudeos`
3. **Validate** with `nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel --dry-run` (every host in the flake)
4. **Check** with `nix flake check`
5. **Format** with `nix fmt`
6. **Apply** with `sudo nixos-rebuild switch --flake ~/.config/claudeos#$(hostname)`
7. **Push** with `git push` — remote rebuilds pull from the repo, so never skip this
8. **Sync** between machines with `git pull`

**Important:** Always modify files in `~/.config/claudeos/` — never edit upstream module files or flake input sources directly.

## Compositor config isn't validated by the build

`nix build` / `nix flake check` only check Nix **evaluation** — they cannot parse the *contents* of a generated `hyprland.conf` or the Quickshell QML. A config that builds green can still be rejected at runtime: e.g. Hyprland 0.55 changed `windowrule` grammar to space-separated (`float class:^(…)$`), so the old comma form (`float, class:…`) builds fine but throws `invalid field float` and raises Hyprland's on-screen config-error banner. Likewise a single broken QML file blanks the entire bar (Quickshell registers the config dir as one module).

So validate **new Hyprland config values against the running binary** before rebuilding. The `system-health` MCP server wraps this workflow as tools: `hypr_config_check` (trials a field/value via `hyprctl keyword`, then restores the deployed config), `hypr_config_errors` (empty = green), and `quickshell_check` (overlays repo QML onto the deployed config and load-checks with `qs -p`; pass `qml_dir` from worktrees). Manual fallback: `hyprctl keyword <field> <value>` must return `ok`, `hyprctl configerrors` must be empty after `hyprctl reload`, and `qs -p <writable copy>/shell.qml` must load with no errors.

## Capabilities

Read `CAPABILITIES.md` for the full system capabilities reference — MCP servers, agents, skills, hooks, desktop integration, and proactive behaviors.

## Debugging / NixOS

When diagnosing NixOS build issues, trace the actual dependency chain (e.g., `nix why-depends`, grep for the package in flake inputs and modules) rather than guessing the source. Do not add config options without verifying they exist in the relevant NixOS module.

**Never write option names or package references from memory** — query the `nixos` MCP server first (it covers NixOS options, packages, home-manager/darwin options, Nix functions via noogle, NixOS Wiki, and version history via `nix_versions`).

## Documentation

Documentation lives in `docs/` and `INSTALL.md` — check there for workflow, deployment, hardware, theme, and troubleshooting details.
