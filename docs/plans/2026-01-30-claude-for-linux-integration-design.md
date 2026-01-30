# Claude-for-Linux Flake Integration Design

**Date**: 2026-01-30
**Status**: Approved for implementation

## Overview

Integrate the claude-for-linux flake (https://github.com/heytcass/claude-for-linux) into ClaudeOS to provide Claude Desktop with Cowork support on Linux alongside the existing Claude Code CLI setup.

## Context

Currently, `modules/apps/claude.nix` provides:
- Claude Code CLI via nix-ld for dynamic library compatibility
- Comments noting Claude Desktop lacks official Linux support

The claude-for-linux flake provides:
- Patched Claude Desktop builds for Linux
- Cowork feature support (screen sharing, computer use)
- Both NixOS and Home Manager modules
- Auto-patching capability for updates

## Design Decisions

### 1. Integration Method
**Decision**: Add Claude Desktop alongside existing Claude Code CLI setup
**Rationale**: Users benefit from both tools - CLI for development, Desktop for interactive use

### 2. Module Type
**Decision**: Use Home Manager module
**Rationale**: Per-user installation, cleaner separation, aligns with ClaudeOS pattern

### 3. Auto-Install
**Decision**: Enable auto-install
**Rationale**: Seamless experience, patches applied automatically on updates

## Implementation

### Flake Input

Add to `flake.nix` inputs:
```nix
claude-for-linux = {
  url = "github:heytcass/claude-for-linux";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Update outputs signature to include `claude-for-linux`.

### Home Manager Integration

In `modules/apps/claude.nix`, add:
```nix
home-manager.users.tom = {
  imports = [ inputs.claude-for-linux.homeManagerModules.default ];

  programs.claude-cowork = {
    enable = true;
    autoInstall = true;
  };
};
```

### Documentation Updates

Update comments in `claude.nix`:
- Remove "no official Linux support" note
- Add claude-for-linux installation details
- Document Cowork features and auto-update behavior

## Testing Plan

1. **Validation** (dev machine):
   - `git add flake.nix modules/apps/claude.nix`
   - `nix flake check`
   - `nix flake lock`
   - `nix build .#nixosConfigurations.transporter.config.system.build.toplevel --dry-run`

2. **Deployment** (transporter test machine):
   - Deploy configuration
   - Verify Claude Desktop in applications menu
   - Test launch and Cowork features
   - Verify auto-update mechanism

3. **Production** (gti):
   - Deploy after successful test on transporter

## Rollback Plan

- `sudo nixos-rebuild switch --rollback` for instant rollback
- Boot previous generation from GRUB
- Set `programs.claude-cowork.enable = false;` to disable

## Benefits

- Claude Desktop available on Linux with full Cowork support
- Auto-patching handles updates seamlessly
- Both CLI and Desktop tools available
- Per-user installation via Home Manager
- Sandboxed via bubblewrap for security
