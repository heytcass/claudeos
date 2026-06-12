# Development Workflow

Configuration lives in `~/.config/claudeos` on each NixOS machine.

## Why ~/.config/claudeos?

Using `~/.config/claudeos` instead of `/etc/nixos`:
- No sudo for editing
- Easier git operations
- Follows XDG Base Directory specification
- Cleaner separation of user config from system files

The rebuild command uses explicit path: `sudo nixos-rebuild switch --flake ~/.config/claudeos#<hostname>`

## Making Changes

### 1. Edit Configuration

Edit `.nix` files in:
- `modules/` - Shared modules (system-level)
- `hosts/` - Machine-specific config
- `home/` - Home Manager user config

### 2. Validate Changes

Always validate before applying:

```bash
# Full validation
nix flake check

# Format code
nix fmt

# Lint for issues
statix check

# Find dead code
deadnix -e
```

Inside Claude Code, the repo-tracked hooks do part of this automatically: every `.nix` edit is nixfmt-formatted and parse-checked (`.claude/hooks/post-edit-check.sh`), and `git commit` with staged `.nix` changes is denied unless `nix flake check --no-build` passes (`.claude/hooks/pre-commit-gate.sh`).

### 3. Apply Changes

Use the fish `rebuild` function (defined in `home/shell/fish.nix`) — this is the standard path:

```fish
rebuild              # full flow
rebuild --no-commit  # skip the auto-commit step
```

What it does:
1. **Names the generation** — haiku summarizes the pending diff into a slug, written to the repo-root `generation-label` file. It becomes the boot-menu label via `system.nixos.tags` (`modules/common/generation-label.nix`), so `nixos-rebuild list-generations` reads like a changelog
2. **Snapper pre snapshots** on root + home, described "pre: \<slug\>"
3. **`nh os switch`** — live build graph via nom, automatic closure diff on activation
4. **Snapper post snapshots** + rollback hint (`sudo snapper -c root undochange N..N+1`)
5. **Auto-commit + push** with a Claude-generated conventional commit message

For a non-persistent test switch: `rebuild-test` (= `nh os test`). The raw command still works too: `sudo nixos-rebuild switch --flake ~/.config/claudeos#$(hostname)` — it just skips the labels and snapshots.

### 4. Commit Changes

`rebuild` auto-commits and pushes on success. For manual commits:

```bash
git add <files>
git commit -m "feat(module): description"
git push origin main
```

Commit message conventions:
- `feat(module): add new feature`
- `fix(module): fix issue`
- `docs: update documentation`
- `refactor(module): refactor code`
- `chore: maintenance task`

### 5. Sync to Other Machines

On the other machine:
```bash
cd ~/.config/claudeos
git pull
rebuild
```

## Common Tasks

### Add New Module

1. Create module file in appropriate category:
   ```bash
   # Example: modules/apps/newtool.nix
   ```

2. Edit `modules/apps/default.nix` to import it:
   ```nix
   imports = [
     ./newtool.nix
   ];
   ```

3. Implement module following conventions (see [MODULES.md](./MODULES.md))

4. Validate and apply:
   ```bash
   nix flake check
   rebuild
   ```

### Update Dependencies

The weekly auto-update timer (`claudeos-auto-update`, Sat 3 AM) handles this automatically: flake update, test build, Claude-reviewed changelog, haiku generation slug, commit + push. Manually:

```bash
# Update all inputs
nix flake update

# Update specific input
nix flake lock --update-input nixpkgs

# Validate after update
nix flake check
```

### Add New Machine

1. Create host directory: `mkdir -p hosts/newmachine`
2. Create `hosts/newmachine/default.nix`:
   ```nix
   { ... }:
   {
     imports = [ ./hardware-configuration.nix ];
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

1. Check formatting: `nix fmt -- --check .`
2. Check for common issues: `statix check`
3. Look for undefined variables: `deadnix -e`
4. Read error message carefully - Nix errors include file and line numbers

### Changes Not Applying

- Did you rebuild? Run `rebuild` (or `nh os switch`)
- Check current generation: `nixos-rebuild list-generations` (generation labels come from `generation-label`)
- Some changes (kernel, boot) need a reboot

## Best Practices

### Do:
- Always validate before applying (`nix flake check`)
- Test on transporter before gti
- Keep modules focused and small
- Use `mkDefault` for overridable defaults
- Comment why, not what
- Follow existing patterns

### Don't:
- Skip validation
- Apply untested changes to production (gti)
- Add global packages — use devShells for projects
- Leave TODO comments without tracking

## Getting Help

- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - Common issues
- [MODULES.md](./MODULES.md) - Module documentation
- Review existing modules for patterns
- Ask questions using AskUserQuestion tool
