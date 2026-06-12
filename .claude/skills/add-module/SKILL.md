---
name: add-module
description: Scaffold a new NixOS module, wire it into imports, and validate
---

# Add NixOS Module

Scaffold a new module following project conventions, wire it in, and validate.

## Usage

`/add-module <category>/<name>` — e.g. `/add-module apps/tailscale` or `/add-module common/firewall`

## Steps

### 1. Determine Location

Categories map to directories:
- `common/` — system foundations (boot, networking, users)
- `desktop/` — GNOME, audio, fonts, theme
- `apps/` — applications and services
- `home/` — home-manager modules (shell, git, etc.)

If category unclear, ask.

### 2. Scaffold Module

Use the **module-creator** subagent, or create directly following the template:

```nix
# modules/<category>/<name>.nix
{ config, lib, pkgs, ... }:
{
  # Configuration here
}
```

For modules with options, use `mkEnableOption` + `mkIf`:
```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.services.<name>;
in {
  options.services.<name> = {
    enable = lib.mkEnableOption "<name> service";
  };

  config = lib.mkIf cfg.enable {
    # ...
  };
}
```

### 3. Wire Into Imports

Add to the category's `default.nix`:
```nix
imports = [
  ./<name>.nix  # Add this line
];
```

For home-manager modules, add to `home/default.nix`.

### 4. Validate

```bash
cd ~/.config/claudeos
git add -N modules/<category>/<name>.nix
nix flake check
# Build all hosts
for host in $(ls hosts/); do
  nix build .#nixosConfigurations.$host.config.system.build.toplevel --dry-run
done
```

### 5. Report

Show the new module path and confirm it builds for all hosts.
