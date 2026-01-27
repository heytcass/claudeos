# Development Workflow

**Development is done on Ubuntu machine, deployment to NixOS targets.**

## Setup Development Environment

### First Time Setup

```bash
cd /home/tom/projects/claudeos

# Initialize flake lock
nix flake update

# Enter development shell
nix develop

# Allow direnv (optional but recommended)
direnv allow
```

### Daily Development

```bash
cd /home/tom/projects/claudeos

# If using direnv, it will auto-load
# Otherwise: nix develop
```

## Making Changes

### 1. Edit Configuration

Edit any `.nix` files in:
- `modules/` - Shared modules
- `hosts/` - Machine-specific config
- `home/` - Home manager config

### 2. Validate Changes

**ALWAYS validate before committing:**

```bash
# Full validation
nix flake check

# Format code
nixpkgs-fmt .

# Lint for issues
statix check

# Find dead code
deadnix -e
```

Or use validator agent:
```bash
@validator-agent check all
```

### 3. Test Build (Optional)

Build without deploying to verify:

```bash
# Build for transporter
nix build .#nixosConfigurations.transporter.config.system.build.toplevel

# Build for gti
nix build .#nixosConfigurations.gti.config.system.build.toplevel
```

Or use builder agent:
```bash
@builder-agent build transporter
```

### 4. Commit Changes

```bash
git add .
git commit -m "feat(module): description"
git push origin main
```

**Commit message conventions:**
- `feat(module): add new feature`
- `fix(module): fix issue`
- `docs: update documentation`
- `refactor(module): refactor code`
- `chore: maintenance task`

## Deployment Workflow

See [DEPLOYMENT.md](./DEPLOYMENT.md) for detailed deployment steps.

**Quick version:**

```bash
# On target machine (transporter or gti)
ssh transporter  # or gti
cd /etc/nixos    # or wherever repo is cloned
git pull
sudo nixos-rebuild switch --flake .#transporter
```

Or use deployer agent from Ubuntu:
```bash
@deployer-agent deploy transporter with message "feat: xyz"
```

## Common Tasks

### Add New Module

1. Create module file in appropriate category:
   ```bash
   # Example: modules/apps/newtool.nix
   touch modules/apps/newtool.nix
   ```

2. Edit `modules/apps/default.nix` to import it:
   ```nix
   imports = [
     ./newtool.nix
   ];
   ```

3. Implement module following conventions (see [MODULES.md](./MODULES.md))

4. Validate and test:
   ```bash
   nix flake check
   nix build .#nixosConfigurations.transporter.config.system.build.toplevel
   ```

Or use module-creator agent:
```bash
@module-creator-agent create modules/apps/newtool.nix
```

### Update Dependencies

```bash
# Update all inputs
nix flake update

# Update specific input
nix flake lock --update-input nixpkgs

# Validate after update
nix flake check
```

### Add New Machine

1. Create host directory:
   ```bash
   mkdir -p hosts/newmachine
   ```

2. Create `hosts/newmachine/default.nix`:
   ```nix
   { config, lib, pkgs, ... }:
   {
     imports = [ ./hardware-configuration.nix ];
     # Machine-specific config
   }
   ```

3. Add to `flake.nix` nixosConfigurations:
   ```nix
   newmachine = lib.mkSystem {
     hostname = "newmachine";
     system = "x86_64-linux";
     user = "tom";
     hardwareModules = [ /* ... */ ];
     modules = [ ./hosts/newmachine ];
     inherit specialArgs;
   };
   ```

4. Generate hardware-configuration.nix on target (see [DEPLOYMENT.md](./DEPLOYMENT.md))

## Troubleshooting

### Build Errors

1. Check syntax:
   ```bash
   nixpkgs-fmt --check .
   ```

2. Check for common issues:
   ```bash
   statix check
   ```

3. Look for undefined variables:
   ```bash
   deadnix -e
   ```

4. Read error message carefully - Nix errors include line numbers

### Flake Check Fails

- Ensure all imports exist
- Check for syntax errors
- Verify module options are defined before use
- Make sure hardware-configuration.nix exists for all hosts

### Can't Enter Dev Shell

- Check `nix --version` - ensure Nix is installed
- Try: `nix develop --refresh`
- Check flake.lock exists: `nix flake update`

### Changes Not Applying

- Did you commit and push?
- Did you pull on target machine?
- Did you rebuild: `sudo nixos-rebuild switch --flake .#<hostname>`?
- Check current generation: `nixos-rebuild list-generations`

## Best Practices

### Do:
- ✅ Always validate before committing (`nix flake check`)
- ✅ Test on transporter before gti
- ✅ Keep modules focused and small (under 200 lines)
- ✅ Use `mkDefault` for overridable defaults
- ✅ Comment why, not what
- ✅ Follow existing patterns
- ✅ Update IMPLEMENTATION_STATUS.md as you work

### Don't:
- ❌ Edit config directly on NixOS machines
- ❌ Skip validation step
- ❌ Commit untested changes
- ❌ Make breaking changes without testing
- ❌ Add global packages - use direnv for projects
- ❌ Leave TODO comments without tracking

## Getting Help

- Read [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)
- Check module documentation: [MODULES.md](./MODULES.md)
- Review existing modules for patterns
- Ask questions using AskUserQuestion tool
