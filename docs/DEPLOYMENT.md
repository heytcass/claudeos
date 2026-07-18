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

# Apply (fish function: generation label + snapper snapshots + nh os switch + auto-commit)
rebuild

# Or the raw command (skips labels/snapshots):
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
- [ ] regreet greets and the "Hyprland (UWSM)" session loads (pick the UWSM entry — the plain one strands session services)
- [ ] Wayland session active (`echo $XDG_SESSION_TYPE`)
- [ ] Claude keybindings work (Super+C, Super+A)
- [ ] Audio works
- [ ] Ghostty terminal launches
- [ ] Fish shell with Starship prompt
- [ ] CLI tools work (eza, bat, zoxide)
- [ ] Chrome launches; comms PWAs (Slack/Discord/Teams) installed via chrome://apps
- [ ] Claude Code CLI works (`claude --version`)

## Post-Install Manual Steps

One-time setup after a fresh installation:

**Note:** Claude Code CLI installs automatically on first login via systemd user service. Verify with `claude --version` after logging in.

1. **SSH keys:** Copy from another machine or generate new ones (git identity is declarative in `home/git.nix`)
2. **Chrome:** Sign in and install extensions
3. **Comms PWAs:** Install Slack/Teams/Discord as Chrome PWAs and sign in to workspaces
4. **VSCode:** Install extensions from the Marketplace (extensions are deliberately not declared — suggested baseline in `home/vscode.nix`)
5. **Calendar (morning desk):** one-time `gcalcli init` with the Google OAuth client from sops

## Disk Space Management

GC is declarative via `programs.nh.clean` (keep 5 generations / 14 days). Manually:

```bash
# Check disk space
df -h

# Clean now with nh
nh clean all --keep 5 --keep-since 14d

# Optimize nix store (auto-optimise is also on)
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

transporter is the testbed; gti is production — test there first when possible:

- Build first: `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` (or `rebuild-test` = `nh os test` for a non-persistent switch)
- The `rebuild` fish function takes named snapper pre/post snapshots automatically
- Keep working generation — don't garbage-collect until verified
- Document issues in TROUBLESHOOTING.md (recurring journal noise goes in docs/known-issues.md)
