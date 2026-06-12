# Secrets Management

Documentation for secrets management in ClaudeOS.

## Current Status

**ClaudeOS uses sops-nix for declarative secrets management.** Secrets are encrypted with age and committed to `secrets/secrets.yaml`. Declarations live in `modules/common/secrets.nix`.

### How decryption works

There is **no separate age key file to manage on the host**. sops-nix uses the host's SSH ed25519 key (`/etc/ssh/ssh_host_ed25519_key`), converted to an age key, to decrypt secrets at activation time. This key exists during early boot — unlike a key stored in a user's home directory — so secrets are available before login.

Decrypted secrets appear at `/run/secrets/<name>` with the owner/mode declared in `modules/common/secrets.nix`.

### Recipients (`.sops.yaml`)

Two age public keys can decrypt `secrets/secrets.yaml`:

| Key | Purpose |
|-----|---------|
| `user` | Tom's personal age key (`~/.config/sops/age/keys.txt`) — used to **edit** secrets |
| `gti_host` | gti's SSH host key converted to age — used by sops-nix to **decrypt at runtime** |

### Declared secrets

`modules/common/secrets.nix` declares six secrets, all owned by the user with mode `0400`, all consumed by the Jasper daemon (`modules/apps/jasper.nix`):

- `jasper_anthropic_api_key`
- `jasper_google_client_id`
- `jasper_google_client_secret`
- `jasper_google_weather_api_key`
- `jasper_google_routes_api_key`
- `jasper_home_address`

All other authentication is handled outside sops-nix:
- **SSH keys:** Stored in `~/.ssh/` with proper permissions (not managed declaratively)
- **GitHub:** `gh` CLI keyring auth; the `with-github-token <cmd>` wrapper materializes the token per-process (no global export)
- **User passwords:** Set during NixOS installation with `passwd`

## Editing Secrets

Editing requires a machine that has the **user age key** at `~/.config/sops/age/keys.txt` (the host key can only decrypt, and only via sops-nix):

```bash
cd ~/.config/claudeos
sops secrets/secrets.yaml   # opens decrypted YAML in $EDITOR
git add secrets/secrets.yaml
git commit -m "chore(secrets): ..."
git push
```

The encrypted file is safe to commit and push. Hosts pick up new values on the next `rebuild`.

## Adding a New Secret

1. On a machine with the user age key: `sops secrets/secrets.yaml` and add the key/value
2. Declare it in `modules/common/secrets.nix`:
   ```nix
   sops.secrets.my_secret = {
     owner = user;
     mode = "0400";
   };
   ```
3. Reference it via `config.sops.secrets.my_secret.path` (resolves to `/run/secrets/my_secret`)
4. Rebuild and verify the file exists with correct ownership

## Planned: `unifi_api_key`

`.mcp.json` registers a UniFi MCP server that reads `UNIFI_API_KEY` from the environment — fish exports it from `/run/secrets/unifi_api_key` when that file exists (`home/shell/fish.nix`). The secret itself is **not yet in `secrets/secrets.yaml`**. Follow-up:

1. Add `unifi_api_key` via `sops secrets/secrets.yaml`
2. Declare `sops.secrets.unifi_api_key` in `modules/common/secrets.nix` (owner = user, mode `0400`)

Until then, the UniFi MCP server simply has no key and the fish export is a no-op.

## Adding a New Host

A new host's SSH host key must be added as a recipient before sops-nix can decrypt on it:

```bash
# On the new host: convert the SSH host key to an age public key
nix shell nixpkgs#ssh-to-age -c sh -c 'ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub'

# Add the printed age1... key to .sops.yaml, then re-encrypt for all recipients
sops updatekeys secrets/secrets.yaml
```

Commit both `.sops.yaml` and the re-encrypted `secrets/secrets.yaml`.

## Key Management

**Backup the user age key** (`~/.config/sops/age/keys.txt`) somewhere secure — without it you cannot edit secrets. The host can still decrypt (its SSH key is the second recipient), but if both are lost the file contents are unrecoverable.

**Rotate a secret:**
```bash
sops secrets/secrets.yaml          # change the value
git commit -am "chore(secrets): rotate ..." && git push
rebuild                            # redeploys /run/secrets/*
```

**Rotate recipients:** update `.sops.yaml`, then `sops updatekeys secrets/secrets.yaml`.

## Security Considerations

**Do:**
- ✅ Keep the user age private key out of the repository and backed up securely
- ✅ Commit encrypted `secrets/secrets.yaml` — it is safe in git
- ✅ Declare every consumed secret in `modules/common/secrets.nix` with explicit owner/mode
- ✅ Reference secrets by `.path` so values never enter the Nix store

**Don't:**
- ❌ Commit private keys or unencrypted secrets
- ❌ Hardcode credentials in tracked files (the UniFi key was moved to the environment for exactly this reason)
- ❌ Put secret values directly in Nix expressions (they end up world-readable in `/nix/store`)

## Reference

- [sops-nix GitHub](https://github.com/Mic92/sops-nix)
- [sops Documentation](https://github.com/getsops/sops)
- [age Encryption](https://github.com/FiloSottile/age)
- [ssh-to-age](https://github.com/Mic92/ssh-to-age)

---

*Last updated: 2026-06-11*
*Status: sops-nix decrypts via the gti host SSH key; 6 jasper_* secrets declared*
