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
- When user requests new module

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

    # Additional options here
    package = mkOption {
      type = types.package;
      default = pkgs.<name>;
      description = "Package to use for <name>";
    };
  };

  config = mkIf cfg.enable {
    # Configuration here
    environment.systemPackages = [ cfg.package ];

    # Services, systemd units, etc.
  };
}
```

## Module Categories

### common/
Namespace: `system` or top-level
Examples: boot, networking, users

### desktop/
Namespace: `desktop` or `services`
Examples: GNOME, audio, fonts

### apps/
Namespace: `programs` or `environment`
Examples: terminals, browsers, communication

### development/
Namespace: `programs` or `development`
Examples: direnv, git, vscode

### services/
Namespace: `services`
Examples: custom services

## Best Practices

### Do:
- Use `mkEnableOption` for enable flags
- Use `mkDefault` for overridable defaults
- Use `mkIf` for conditional configuration
- Keep modules under 200 lines
- Group related options together
- Comment complex logic
- Use meaningful variable names

### Don't:
- Hardcode values - use options
- Make modules too large
- Forget to use `mkIf` with `enable`
- Create circular dependencies
- Duplicate code between modules

## Integration Steps

After creating module:

1. **Add to category default.nix:**
```nix
# modules/<category>/default.nix
{
  imports = [
    ./existing.nix
    ./newmodule.nix  # Add this line
  ];
}
```

2. **Test validation:**
```bash
nix flake check
```

3. **Document module:**
Run doc-generator agent or manually add to MODULES.md

4. **Test build:**
```bash
nix build .#nixosConfigurations.transporter.config.system.build.toplevel
```

## Usage Examples

**User:** "Create a module for GNOME"
**Agent:** Generate modules/desktop/gnome.nix with GNOME configuration

**User:** "Add a module for WezTerm"
**Agent:** Create modules/apps/terminals.nix with WezTerm

**User:** "Scaffold direnv module"
**Agent:** Generate modules/development/direnv.nix

## Module Examples

### Simple Enable Module

```nix
{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    programs.tool.enable = true;
    environment.systemPackages = with pkgs; [ tool ];
  };
}
```

### Module with Options

```nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.mytool;
in {
  options.programs.mytool = {
    enable = mkEnableOption "mytool";

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Extra configuration";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.mytool ];

    environment.etc."mytool/config".text = ''
      # Default config
      ${cfg.extraConfig}
    '';
  };
}
```

### Service Module

```nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.myservice;
in {
  options.services.myservice = {
    enable = mkEnableOption "myservice";

    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Port to listen on";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.myservice = {
      description = "My Service";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.myservice}/bin/myservice --port ${toString cfg.port}";
        Restart = "always";
      };
    };
  };
}
```

## Validation Checklist

After creating module:
- [ ] Follows template structure
- [ ] Has enable option
- [ ] Uses mkIf for conditional config
- [ ] No hardcoded values
- [ ] Added to category default.nix
- [ ] Passes `nix flake check`
- [ ] Documented in MODULES.md
- [ ] Tested with build

## Common Patterns

### Package Installation
```nix
environment.systemPackages = with pkgs; [ package ];
```

### Service Configuration
```nix
systemd.services.name = { ... };
```

### User-Level Configuration
```nix
home-manager.users.<user> = { ... };
```

### Configuration File
```nix
environment.etc."app/config.toml".text = ''
  content here
'';
```

### Override Package
```nix
nixpkgs.overlays = [
  (self: super: {
    package = super.package.overrideAttrs (old: { ... });
  })
];
```
