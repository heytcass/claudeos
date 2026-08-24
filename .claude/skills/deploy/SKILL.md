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
nix fmt -- --ci .
```

**Stop on failure.** Fix before continuing.

`--ci` is the formatting gate, not `--check` — treefmt has no `--check`
flag, so that spelling makes it print its help and exit 1 on every run,
whether or not anything is misformatted. `--ci` implies `--no-cache
--fail-on-change`: exit 0 when the tree is clean, 1 when a file would
change. Read the `N changed` count in its output, not a piped `$?` —
`cmd | tail` reports tail's status and will mask a real failure.

### 3. Deploy from a clean tree

`flake.nix` sets `system.configurationRevision = self.shortRev or "dirty"`.
Nix omits `shortRev` entirely when the working tree is dirty, so the
fallback fires and the generation is stamped `dirty` instead of a commit —
`nixos-rebuild list-generations` then can't tell you what is actually
running, and neither can the other host.

Check first, and confirm with the user before touching their work:

```bash
git status --short
nix eval --raw .#nixosConfigurations.<host>.config.system.configurationRevision
```

If that prints `dirty`, resolve it — commit the changes if they are ready,
or park unrelated work-in-progress for the duration of the deploy:

```bash
git stash push -m "wip: <what>" -- <paths>   # ... deploy ... then:
git stash pop
```

Restore the stash in the same turn, even if the build or switch fails.

### 4. Build

```bash
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
```

**Stop on failure.** Do not proceed to apply.

### 5. Apply

```bash
sudo nixos-rebuild switch --flake ~/.config/claudeos#<host>
```

If deploying to a host other than `$(hostname)`, confirm with user first.

### 6. Verify

```bash
nixos-rebuild list-generations | head -3
```

Report the new generation number *and* its Configuration Revision — the
revision is the check that step 3 held. It should be the commit you
deployed; `dirty` means the generation does not correspond to anything
committed, so nothing can reproduce or roll back to it by hash.

Confirm the switch's final store path matches what step 4 built, then ask
the user to verify the target functionality. Prefer checking whatever the
build could not: `nix build` only evaluates Nix, so Hyprland config and
Quickshell QML are unverified by everything above (see CLAUDE.md).
