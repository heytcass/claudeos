# sops-nix Declarative Secrets — Design

**Date:** 2026-02-14
**Status:** Approved
**Scope:** Jasper API key + Atuin sync key (gti only)

## Goal

Replace Jasper's runtime SOPS/age decryption with sops-nix declarative secrets. Centralise all secrets in the claudeos repo. Unblock Atuin cross-machine sync.

## Architecture

sops-nix decrypts `secrets/secrets.yaml` during NixOS activation (before services start) using the age key at `~/.config/sops/age/keys.txt`. Plaintext secrets land in `/run/secrets/<name>` with strict file permissions.

Jasper reads the API key via its `ANTHROPIC_API_KEY` env var fallback — no more `sops`/`age` on the service PATH.

## File Layout

```
.sops.yaml                    # Creation rules (gti age public key)
secrets/secrets.yaml           # Encrypted (safe to commit)
modules/common/secrets.nix     # sops-nix config + secret declarations
```

## Secrets

| Secret name               | Source                              | Consumer       |
|---------------------------|-------------------------------------|----------------|
| jasper_anthropic_api_key  | Migrated from ~/Projects/jasper/    | jasper.nix      |
| atuin_key                 | Placeholder (user adds value later) | cli-tools.nix   |

## Module Changes

### modules/common/secrets.nix (new)

- `sops.defaultSopsFile` → `../../secrets/secrets.yaml`
- `sops.age.keyFile` → `/home/tom/.config/sops/age/keys.txt`
- Declares `jasper_anthropic_api_key` and `atuin_key` secrets with `owner = "tom"`, `mode = "0400"`

### modules/apps/jasper.nix (modified)

- Remove: `path = [ pkgs.sops pkgs.age ]` and `JASPER_SOPS_PATH` env var
- Add: wrapper script that reads `/run/secrets/jasper_anthropic_api_key` into `ANTHROPIC_API_KEY` env var, then exec's the daemon

### modules/common/default.nix (modified)

- Import `./secrets.nix`

### home/shell/cli-tools.nix (modified)

- Update Atuin comment — sync ready when key is added

### docs/SECRETS.md + docs/IMPLEMENTATION_STATUS.md (updated)

- Status from "future" to "implemented"

## Key Decisions

- **gti only** — transporter can be added later with its own age key
- **Secrets in claudeos repo** — single source of truth, standard sops-nix pattern
- **Env var fallback** — cleaner than keeping sops/age on PATH for runtime decryption
- **Atuin as placeholder** — declare the secret now, user adds value when ready

## Manual Steps

1. Create `.sops.yaml` (automated)
2. Run `sops secrets/secrets.yaml` to create encrypted file (user)
3. `nixos-rebuild build --flake .` to verify (automated)
4. Test Jasper service with new secret path (user)
