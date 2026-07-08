---
name: deploy
description: Validate, build, and deploy NixOS configuration to a target host
---

# Deploy NixOS Configuration

Full deployment pipeline: validate → build → apply.

## Usage

`/deploy` or `/deploy <hostname>`

## Steps

### 1. Determine Target

If no host specified, default to `$(hostname)` (current machine). If deploying to a different host, confirm with user. List available hosts from `hosts/` directory.

### 2. Validate (stages untracked files itself)

`claudeos-validate` is the canonical validation — it stages untracked
files (flakes only see tracked ones), runs `nix flake check`, and
dry-run-builds every host the flake defines:

```bash
claudeos-validate
nix fmt -- --check .
```

**Stop on failure.** Fix before continuing.

### 3. Build

```bash
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
```

**Stop on failure.** Do not proceed to apply.

### 4. Apply

```bash
sudo nixos-rebuild switch --flake ~/.config/claudeos#<host>
```

If deploying to a host other than `$(hostname)`, confirm with user first.

### 5. Verify

Report the new generation number:
```bash
nixos-rebuild list-generations | head -3
```

Ask user to verify target functionality works.
