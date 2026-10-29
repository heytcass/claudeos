---
name: deploy
description: Validate, land, and deploy NixOS configuration to a target host
---

# Deploy NixOS Configuration

Full pipeline: validate → land on main → apply. A host only ever deploys
**main**, from the shared checkout `~/.config/claudeos`. Session work lives in
its own worktree and reaches the host by landing (CLAUDE.md, "Workflow").

## Usage

`/deploy` or `/deploy <hostname>`

## Steps

### 1. Determine Target

If no host specified, default to `$(hostname)` (current machine). If deploying to a different host, confirm with user. List available hosts from `hosts/` directory.

### 2. Validate (stages untracked files itself)

`claudeos-validate` is the canonical validation — it stages untracked
files (flakes only see tracked ones), runs `nix flake check`, and
dry-run-builds every host the flake defines. It validates the checkout you
are standing in (your worktree), not the shared one:

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

Hyprland config and Quickshell QML are invisible to both (CLAUDE.md,
"Compositor config isn't validated by the build") — run `hypr_config_check`
/ `quickshell_check` (pass `qml_dir` = your worktree's `home/quickshell`)
for anything that touched them.

### 3. Land and apply this host

Commit with explicit paths (never `git add -A`), then from the worktree:

```bash
claudeos-land
```

It rebases on origin/main, names the generation, re-runs
`claudeos-validate`, pushes, opens or reuses the PR, waits for its required
CI (about a minute; a PR touching flake.lock, flake.nix or validate.yml also waits on lock-gate's gti build and VM boot), squash-merges it
(only the exact validated head), fast-forwards `~/.config/claudeos`, runs
`nixos-rebuild switch` there for `$(hostname)` (scoped NOPASSWD — no prompt),
and sweeps landed worktrees. Run it in the background; CI and the switch take
minutes. `--no-deploy` stops after the merge.

It refuses — and says why — rather than deploy a half state: uncommitted
changes in the worktree, a rebase conflict, a failed validation, a PR that
won't merge, or uncommitted config in the shared checkout.

Never deploy from a worktree (`nixos-rebuild --flake <worktree>#…`): the
generation would run code main doesn't have, and the next host to pull
would silently drop it.

### 4. Other hosts

After landing, a remote host deploys main the same way:

```bash
ssh <hostname> "cd ~/.config/claudeos && git pull --ff-only && sudo nixos-rebuild switch --flake ~/.config/claudeos#\$(hostname)"
```

Confirm with the user first.

### 5. Verify

```bash
nixos-rebuild list-generations | head -3
```

Report the new generation number *and* its Configuration Revision. It
should be the squash commit that landed; `dirty` means the shared checkout
had uncommitted changes and the generation corresponds to nothing
committed (`flake.nix` stamps `self.shortRev or "dirty"`).

Then ask the user to verify the target functionality — prefer checking
whatever the build could not.
