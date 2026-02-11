# Troubleshooting Guide

## Build Issues

### Flake Check Fails

**Symptom:** `nix flake check` reports errors

**Solutions:**
1. Check syntax: `nixpkgs-fmt --check .`
2. Check for common issues: `statix check`
3. Look for undefined variables: `deadnix -e`
4. Read error message carefully - includes file and line number
5. Verify all imports exist
6. Ensure changes are staged (`git add`) — flakes only see tracked files

### Build Fails with "attribute missing"

**Symptom:** Error about missing package or option

**Solutions:**
1. Check package name: `nix search nixpkgs <package>`
2. Verify unfree packages enabled if needed
3. Check option exists on [search.nixos.org](https://search.nixos.org/options)

## Deployment Issues

### Rebuild Fails

**Symptom:** `nixos-rebuild switch` fails

**Solutions:**
1. Check error message carefully
2. Verify git repo is up to date: `git status`, `git pull`
3. Check disk space: `df -h`
4. Try rollback: `sudo nixos-rebuild switch --rollback`
5. Check logs: `journalctl -xe`

### Changes Not Applying

**Solutions:**
1. Did you rebuild? `sudo nixos-rebuild switch --flake ~/.config/claudeos#$(hostname)`
2. Check generation changed: `nixos-rebuild list-generations`
3. Some changes need a reboot (kernel, boot loader)
4. Flakes only see staged/committed files — run `git add` first

## Hardware Issues

### Home Directory Ownership After Install

**Symptom:** Permission errors after fresh installation

**Fix:** `sudo chown -R tom:users /home/tom`

One-time issue after NixOS installation.

### Package Renames

Nixpkgs occasionally renames packages. Common ones encountered:
- `noto-fonts-emoji` → `noto-fonts-color-emoji`
- `nerdfonts.override` → individual `nerd-fonts.*` packages

**Fix:** Update package names in the relevant module.

## Application Issues

### Claude Code CLI Not in PATH

**Symptom:** `claude` command not found

**Solutions:**
```bash
# Verify installation
ls -la ~/.local/bin/claude

# Re-install if needed
curl -fsSL https://claude.ai/install.sh | bash

# Reload Fish config
source ~/.config/fish/config.fish
```

PATH is configured in `home/shell/fish.nix` via `fish_add_path ~/.local/bin`.

### Unwanted Launcher Icons

**Symptom:** CLI tools appear in application launcher

**Fix:** Hide via Home Manager in `home/default.nix` using `NoDisplay=true` desktop entries, or at system level via `services.xserver.excludePackages`.

### Fish Plugin Hash Mismatch

**Symptom:** Build fails with hash mismatch for Fish plugins

**Fix:** Use the "got:" hash from the error message and update it in `home/shell/fish.nix`.

## Runtime Issues

### Service Won't Start

**Solutions:**
1. Check status: `systemctl status <service>`
2. Check logs: `journalctl -u <service>`
3. Verify service is enabled in configuration
4. Try starting manually: `systemctl start <service>`

### Audio Issues

```bash
# Check Pipewire status
systemctl --user status pipewire pipewire-pulse wireplumber

# List audio devices
pactl list sinks
```

### Network Issues

```bash
# NetworkManager status
nmcli device status
nmcli connection show

# WiFi networks
nmcli device wifi list
```

## Rollback

```bash
# List generations
sudo nixos-rebuild list-generations

# Rollback to previous
sudo nixos-rebuild switch --rollback

# Or select from systemd-boot menu at boot
```

## Known Limitations

1. **sops-nix not configured** — no declarative secrets management yet (see SECRETS.md)
2. **Atuin sync disabled** — shell history not synced across machines
3. **Git identity not configured** — set manually with `git config --global`
4. **VSCode Claude extension** — must install manually (VSCode limitation)
5. **Chrome extensions** — must install manually (browser limitation)

## Getting Help

- [MODULES.md](./MODULES.md) - Module documentation
- [NixOS Wiki](https://wiki.nixos.org)
- [NixOS Discourse](https://discourse.nixos.org)
- Ask the user with AskUserQuestion tool
