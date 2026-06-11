# Deployment Guide

## Initial NixOS Installation

For fresh installations, use the disko-based installer. See [INSTALL.md](../INSTALL.md) and [DISKO.md](./DISKO.md) for full instructions.

Quick summary:
1. Boot NixOS installer USB
2. Clone repo and run `install-with-disko.sh <hostname>`
3. Set passwords and reboot
4. Fix home directory ownership: `sudo chown -R tom:users /home/tom`

## Local Rebuild (Primary Method)

After editing configuration in `~/.config/claudeos`:

```bash
# Validate
nix flake check

# Apply
sudo nixos-rebuild switch --flake ~/.config/claudeos#$(hostname)
```

## Deploy to Another Machine

### Via SSH + git

```bash
# On the remote machine
ssh <hostname>
cd ~/.config/claudeos
git pull origin main
sudo nixos-rebuild switch --flake ~/.config/claudeos#$(hostname)
```

### Via nixos-rebuild --target-host

From the local machine (requires SSH key and passwordless sudo on target):

```bash
nixos-rebuild switch --flake .#<hostname> \
  --target-host tom@<hostname> \
  --use-remote-sudo \
  --build-host tom@<hostname>
```

## Rollback

If something breaks:

```bash
# List generations
sudo nixos-rebuild list-generations

# Rollback to previous generation
sudo nixos-rebuild switch --rollback

# Or boot specific generation from systemd-boot menu
```

## Post-Deployment Verification

After applying a new configuration:

- [ ] System boots / services running
- [ ] Niri session loads with Noctalia bar
- [ ] Wayland session active (`echo $XDG_SESSION_TYPE`)
- [ ] Audio works
- [ ] Ghostty terminal launches
- [ ] Fish shell with Starship prompt
- [ ] CLI tools work (eza, bat, zoxide)
- [ ] Chrome, Slack, Discord launch
- [ ] Claude Code CLI works (`claude --version`)

## Post-Install Manual Steps

One-time setup after a fresh installation:

**Note:** Claude Code CLI installs automatically on first login via systemd user service. Verify with `claude --version` after logging in.

1. **Git identity:** `git config --global user.name "Name"` and `git config --global user.email "email"`
2. **SSH keys:** Copy from another machine or generate new ones
3. **Chrome:** Sign in and install extensions
4. **Slack/Discord:** Sign in to workspaces
5. **VSCode:** Install Claude extension from marketplace

## Disk Space Management

```bash
# Check disk space
df -h

# Clean old generations (keep last 30 days)
sudo nix-collect-garbage --delete-older-than 30d

# Optimize nix store
nix store optimise
```

## Security

- Set strong passwords for root and user
- Configure SSH key authentication
- Disable password SSH after key setup:
  ```nix
  services.openssh.settings.PasswordAuthentication = lib.mkForce false;
  ```
- Never commit unencrypted secrets
- Update flake inputs regularly: `nix flake update` (the weekly auto-update timer also handles this)

## Testing Strategy

gti is the only host, so there is no staging machine — test before switching:

- Build first: `nix build .#nixosConfigurations.gti.config.system.build.toplevel` (or `rebuild-test` for a non-persistent switch)
- The `rebuild` fish function takes snapper pre/post snapshots automatically
- Keep working generation — don't garbage-collect until verified
- Document issues in TROUBLESHOOTING.md
