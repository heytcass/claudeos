---
name: deploy
description: Validate, build, and deploy NixOS configuration to a target host
---

# Deploy NixOS Configuration

Full deployment pipeline: validate → build → apply.

## Usage

`/deploy` or `/deploy transporter` or `/deploy gti`

## Steps

### 1. Determine Target

If no host specified, ask:
- **transporter** (test machine — safe to break)
- **gti** (production — confirm before applying)

### 2. Stage New Files

Nix flakes only see tracked files:
```bash
git -C ~/.config/claudeos add -N $(git -C ~/.config/claudeos ls-files --others --exclude-standard)
```

### 3. Validate

Dispatch the **validator** subagent, or run directly:
```bash
cd ~/.config/claudeos
nix flake check
nix fmt -- --check .
```

**Stop on failure.** Fix before continuing.

### 4. Build

```bash
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
```

**Stop on failure.** Do not proceed to apply.

### 5. Apply

For **transporter** — apply directly:
```bash
sudo nixos-rebuild switch --flake ~/.config/claudeos#transporter
```

For **gti** — confirm with user first, then:
```bash
sudo nixos-rebuild switch --flake ~/.config/claudeos#gti
```

### 6. Verify

Report the new generation number:
```bash
nixos-rebuild list-generations | head -3
```

Ask user to verify target functionality works.
