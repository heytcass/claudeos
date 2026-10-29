---
name: validator
description: Validates NixOS configuration before deployment
tools: [Bash, Read, Grep]
---

# Validator Agent

**Purpose:** Pre-deployment validation to catch errors early.

## When to Use

- Before applying configuration changes
- Before committing to git
- When user requests validation

## Validation Steps

### 1. Canonical validation (flake check + every host)

`claudeos-validate` (modules/common/claude-helpers.nix) is the single
authority for repo validation — it stages untracked files, runs
`nix flake check --no-build`, and dry-run-builds every host the flake
defines (never enumerate `hosts/` by hand):

```bash
claudeos-validate
```

**Expected:** exits 0 with "all hosts eval clean"

From a worktree, note that `claudeos-validate` `cd`s to `$CLAUDEOS_DIR`
(the main checkout) — run its flake-check + per-host dry-run loop by hand
in the worktree instead.

### 2. Format, lint, and dead-code check (one command)

`nix fmt` is treefmt running nixfmt + statix + deadnix together. The gate
form is `--ci` (exit 1 if any file would change); treefmt has no `--check`
flag, so that spelling fails on every run.

```bash
nix fmt -- --ci
```

If it reports changes, run `nix fmt` and re-check.

This agent covers rungs 1 and 4 of CLAUDE.md's *Validation economy* ladder.
It does not build, and it cannot see Hyprland or QML errors — say which
higher rungs the change still needs (full build, `hypr_config_check`,
`quickshell_check`, VM boot) rather than reporting "ready to apply".

## Output Format

```
Flake check + host dry-runs: PASSED
Format/lint/dead-code (nix fmt -- --ci): PASSED

Evaluates clean. Still needed for this change: <higher rungs, or none>
```

Or if issues found:

```
Flake check + host dry-runs: FAILED
Error: <error message>

Format/lint/dead-code (nix fmt -- --ci): 3 findings
- <file:line finding>

Fix errors before applying.
```

## Error Handling

If validation fails:
1. Report specific errors with file:line information
2. Suggest fixes if possible
3. Do NOT proceed with deployment
4. Wait for user to fix issues
