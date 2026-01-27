# Phase 3: Applications & Shell - Design Document

**Date:** 2026-01-27
**Status:** Approved
**Phase:** 3 of 6

## Overview

Phase 3 implements user-facing applications, modern shell environment, and development tools. This phase focuses on creating a productive environment for daily work and Claude Code workflow.

## Goals

1. Deploy modern shell with Fish, Starship, and CLI tools
2. Install WezTerm as primary terminal (Claude-branded)
3. Setup browsers and communication tools
4. Configure development environment with direnv and VSCode
5. Integrate everything via Home Manager

## Architecture

### Home Manager Integration

Home Manager is integrated as a NixOS module (not standalone) via `lib/mkSystem.nix`:
- Configuration: `home/default.nix`
- Applied to user: `tom`
- Uses global pkgs and special args

### Module Categories

**home/** - User-specific configuration (via Home Manager)
- `shell/` - Fish, CLI tools, Starship
- `wezterm.nix` - Terminal emulator config
- `git.nix` - Git user config
- `vscode.nix` - VSCode user config

**modules/apps/** - System applications
- `terminals.nix` - WezTerm installation
- `browsers.nix` - Chrome
- `communication.nix` - Slack, Discord

**modules/development/** - Development tools
- `direnv.nix` - Per-project environments
- `git.nix` - Git system config
- `vscode.nix` - VSCode installation

## Detailed Design

### 1. Shell Configuration (home/shell/)

#### fish.nix - Full Fish customization
- **Plugins:** fzf.fish, z, puffer-fish (text expansion)
- **Custom functions:** mkcd, extract, git shortcuts
- **Aliases:** Integrate eza, bat, modern CLI tools
- **Abbreviations:** Expand as you type (git shortcuts, system commands)
- **Features:** Colored man pages, history, completion
- **Key bindings:** Default Emacs-style (Vi optional)

#### cli-tools.nix - Modern CLI ecosystem
- **eza:** ls replacement with icons, git integration, color
- **zoxide:** Smart cd with frecency tracking
- **bat:** cat with syntax highlighting, git diff integration
- **atuin:** History search (installed but not configured for sync)
- **yazi:** TUI file manager with image previews
- **ripgrep, fd, fzf:** Fast searching tools
- **Integration:** Tools configured to work together (fzf uses bat for preview)

#### starship.nix - Clean prompt
- **Display:** directory, git (branch + status), exit status
- **Indicators:** Nix shell detection
- **Format:** Single-line, fast, minimal
- **Icons:** Glyphs used sparingly
- **Performance:** No slow language version detection

### 2. Terminal Emulator (home/wezterm.nix)

**Claude-branded WezTerm:**
- **Font:** Inter for UI (matches Claude aesthetic), JetBrains Mono Nerd Font for glyphs
- **Theme:** Custom dark colors inspired by Anthropic brand (deep blues, warm oranges)
- **UI:** Tab bar disabled, clean padding, minimal chrome
- **Performance:** GPU acceleration enabled
- **Key bindings:** Standard + CMD/CTRL+T (new tab), CMD/CTRL+W (close)
- **Cursor:** Steady block, visible
- **Config:** Lua configuration via Home Manager

### 3. Git Configuration

#### home/git.nix - User Git config
- **Identity:** user.name and user.email left unconfigured (manual or Phase 5 secrets)
- **Aliases:** st, co, br, ci, last
- **Workflow:** main branch, rebase on pull, simple push
- **UI:** Colors enabled, delta integration for diffs
- **Integration:** Works with bat themes

#### modules/development/git.nix - System Git
- **Package:** Ensure git available system-wide
- **System config:** Minimal, user config via Home Manager

### 4. VSCode Configuration

#### home/vscode.nix - User VSCode config
- **Extensions:**
  - jnoortheen.nix-ide (Nix language support)
  - mkhl.direnv (direnv integration)
  - arrterian.nix-env-selector (Nix environment)
  - anthropic.claude-dev (Claude Code extension)
- **Settings:**
  - Formatter: nixpkgs-fmt
  - Auto-save: onFocusChange
  - Font: JetBrains Mono with ligatures
  - Theme: Default Dark+
  - Terminal: Fish shell

#### modules/development/vscode.nix - System VSCode
- **Package:** Install vscode
- **Integration:** Desktop file for launcher

### 5. Applications

#### modules/apps/terminals.nix
- Install wezterm package
- Only terminal in launcher (gnome-console, xterm already excluded)

#### modules/apps/browsers.nix
- Install google-chrome (unfree)
- Manual extension and sync setup

#### modules/apps/communication.nix
- Install slack (unfree)
- Install discord (unfree)
- Manual login required

### 6. Development Tools

#### modules/development/direnv.nix
- Enable direnv system-wide
- Integrate nix-direnv for flake support
- Hook into Fish shell
- Enable per-project .envrc for automatic environment loading

## Implementation Order

1. **Create home/shell/ modules** (fish, cli-tools, starship)
2. **Create home/ user configs** (wezterm, git, vscode)
3. **Update home/default.nix** to import all modules
4. **Create modules/apps/ system apps** (terminals, browsers, communication)
5. **Update modules/apps/default.nix** to import modules
6. **Create modules/development/** (direnv, git, vscode)
7. **Update modules/development/default.nix** to import modules
8. **Validate:** git add, nix flake check, dry-run build
9. **Update documentation:** IMPLEMENTATION_STATUS.md
10. **Commit changes**
11. **Deploy to transporter**

## Module Patterns

Following existing code patterns from modules/common/ and modules/desktop/:
- Start with `{ config, lib, pkgs, ... }:`
- Use `lib.mkDefault` for overridable options
- Comments explain "why", not "what"
- Keep modules under 200 lines
- Group related settings logically
- No hardcoded user-specific data

## Validation

```bash
# Stage files (required for flakes)
git add home/ modules/apps/ modules/development/

# Validate flake
nix flake check

# Test build (dry-run)
nix build .#nixosConfigurations.transporter.config.system.build.toplevel --dry-run
```

## Deployment

After validation passes:
```bash
git commit -m "feat(phase3): implement applications and shell configuration"
git push
ssh tom@10.0.10.205
cd ~/.config/claudeos && git pull
sudo nixos-rebuild switch --flake .#transporter
```

## Success Criteria

- [ ] All modules validate with `nix flake check`
- [ ] Dry-run build succeeds
- [ ] Fish shell is default with modern CLI tools
- [ ] Starship prompt displays correctly
- [ ] WezTerm launches with Claude-branded theme
- [ ] Chrome, Slack, Discord appear in launcher
- [ ] VSCode opens with Nix extensions
- [ ] direnv works with test .envrc
- [ ] Only WezTerm appears as terminal in launcher

## Design Decisions

### Why Home Manager as NixOS module?
- Unified deployment (single nixos-rebuild command)
- Shared specialArgs between system and home config
- Consistent state management
- Simpler for single-user machines

### Why Fish over Bash/Zsh?
- Better out-of-box experience
- Superior auto-completion
- Readable configuration syntax
- Already set as user shell in Phase 1

### Why WezTerm over Alacritty/Kitty?
- GPU-accelerated and fast
- Excellent Wayland support
- Rich Lua configuration
- Good font rendering (important for Claude branding)

### Why Inter font for terminal?
- Matches Claude UI aesthetic
- Excellent readability
- Modern, clean look
- Already installed in Phase 2

### Why direnv?
- Essential for multi-project workflow
- Automatic environment loading
- Nix flake support
- Already used in jasper, home-assistant-addons projects

## Future Enhancements

- Custom Fish theme matching Starship
- WezTerm multiplexer configuration
- Atuin sync setup in Phase 5 (secrets)
- Additional VSCode themes (Claude-branded)
- Custom eza colors matching theme
- Git commit signing (Phase 5 with secrets)

## Notes

- All unfree packages (Chrome, Slack, Discord) already allowed by modules/common/nix.nix
- Git identity left unconfigured; will use manual setup or sops-nix in Phase 5
- VSCode and application logins/auth are manual (can't be declarative)
- Module structure follows established patterns from Phase 1 and 2
- No breaking changes to existing configuration
