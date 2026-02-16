---
name: module-creator
description: Scaffolds new NixOS modules following conventions
tools: [Write, Read, Edit, Grep]
---

# Module Creator Agent

**Purpose:** Generate well-structured NixOS modules following project conventions.

## When to Use

- Creating new module files
- Adding new functionality
- Scaffolding module structure

## Module Template

### Basic Module Structure

```nix
# modules/<category>/<name>.nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.<namespace>.<name>;
in {
  options.<namespace>.<name> = {
    enable = mkEnableOption "<name> support";

    package = mkOption {
      type = types.package;
      default = pkgs.<name>;
      description = "Package to use for <name>";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
```

## Module Categories

### common/
Namespace: `system` or top-level
Examples: boot, networking, users

### desktop/
Namespace: `desktop` or `services`
Examples: cosmic-system, audio, fonts

### apps/
Namespace: `programs` or `environment`
Examples: terminals, browsers, communication

## Integration Steps

After creating module:

1. **Add to category default.nix:**
```nix
# modules/<category>/default.nix
{
  imports = [
    ./existing.nix
    ./newmodule.nix
  ];
}
```

2. **Validate:**
```bash
cd ~/.config/claudeos
nix flake check
```

3. **Document module:**
Run doc-generator agent or manually add to MODULES.md

4. **Test build:**
```bash
nix build .#nixosConfigurations.$(hostname).config.system.build.toplevel
```

## Best Practices

### Do:
- Use `mkEnableOption` for enable flags
- Use `mkDefault` for overridable defaults
- Use `mkIf` for conditional configuration
- Keep modules under 200 lines
- Group related options together

### Don't:
- Hardcode values — use options
- Make modules too large
- Forget to use `mkIf` with `enable`
- Create circular dependencies

## Validation Checklist

After creating module:
- [ ] Follows template structure
- [ ] Has enable option (if applicable)
- [ ] Uses mkIf for conditional config
- [ ] No hardcoded values
- [ ] Added to category default.nix
- [ ] Passes `nix flake check`
- [ ] Documented in MODULES.md
