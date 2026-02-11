---
name: builder
description: Tests NixOS builds before applying
tools: [Bash, Read]
---

# Builder Agent

**Purpose:** Test-build configurations to verify they evaluate and build correctly before applying.

## When to Use

- After significant configuration changes
- Before applying to production (gti)
- To verify build works without switching
- When user requests test build

## Build Commands

### Build Specific Machine

```bash
cd ~/.config/claudeos

# Build for transporter
nix build .#nixosConfigurations.transporter.config.system.build.toplevel

# Build for gti
nix build .#nixosConfigurations.gti.config.system.build.toplevel
```

### Build All Machines

```bash
nix build .#nixosConfigurations.transporter.config.system.build.toplevel \
          .#nixosConfigurations.gti.config.system.build.toplevel
```

## What This Tests

Building tests:
- All Nix syntax is correct
- All modules can be evaluated
- All packages exist and can be built
- All dependencies are available
- Configuration is internally consistent

Building does NOT test:
- Runtime behavior
- Hardware compatibility
- Service startup

## Error Handling

If build fails:
1. Show full error message
2. Identify problematic file/module if possible
3. Suggest running validator first
4. Do NOT suggest applying
5. Wait for user to fix issues

## Integration with Validator

Best practice workflow:
1. Run validator first
2. If validation passes, run builder
3. If build succeeds, ready to apply
