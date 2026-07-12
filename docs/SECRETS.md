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

`modules/common/secrets.nix` declares seven secrets, all owned by the user with mode `0400`. Five are Jasper's personal-world credentials (`jasper_anthropic_api_key` was retired with the daemon — removed from both the declaration and the yaml on 2026-07-11; the lane rides the Claude subscription):

- `jasper_google_client_id` / `jasper_google_client_secret` — the Google OAuth app for the one-time `gcalcli init` (calendar); also reused by `morning-desk.nix`
- `jasper_google_weather_api_key` — reserved (the lane currently uses keyless wttr.in)
- `jasper_google_routes_api_key` / `jasper_home_address` — reserved for the future Routes travel-time enhancement (see `modules/apps/jasper.nix`)

plus `unifi_api_key` (fish exports `UNIFI_API_KEY` from its path for the UniFi MCP server).

All other authentication is handled outside sops-nix:
- **SSH keys:** Stored in `~/.ssh/` with proper permissions (not managed declaratively)
- **GitHub, interactive:** `gh` CLI keyring auth; the `with-github-token <cmd>` wrapper materializes the token per-process (no global export)
- **GitHub, headless automation:** the keyring is locked outside a graphical session, and lingering means auto-update/self-heal can run in exactly that state. The pending `github_automation_token` sops secret (fine-grained PAT, this repo only) is exported as `GH_TOKEN` by the agent-script preamble (`claudeos_export_gh_token` in `lib/claude-script.nix`) when present; until it's minted, headless runs degrade to commit-locally + notify.
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

## Planned: `github_automation_token`

The headless automation lane (see above) needs a GitHub credential that works with no session. Follow-up:

1. Mint a fine-grained PAT at github.com/settings/personal-access-tokens — scope it to the claudeos repo only, contents + pull-requests read/write
2. Add it: `sops set secrets/secrets.yaml '["github_automation_token"]' '"<PAT>"'`
3. Uncomment the `sops.secrets.github_automation_token` block in `modules/common/secrets.nix` and rebuild

Until then, headless auto-update runs commit locally and notify instead of pushing, and headless self-heal runs skip with a notification instead of burning an agent session that can't open a PR.

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
