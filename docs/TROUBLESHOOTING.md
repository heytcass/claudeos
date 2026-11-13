# Troubleshooting Guide

## Build Issues

### Flake Check Fails

**Symptom:** `nix flake check` reports errors

**Solutions:**
1. Check formatting: `nix fmt -- --check .`
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

**Symptom:** `rebuild` (nh os switch) or `nixos-rebuild switch` fails

**Solutions:**
1. Check error message carefully (nom shows the failing derivation in the build graph)
2. Verify git repo is up to date: `git status`, `git pull`
3. Check disk space: `df -h`
4. Try rollback: `sudo nixos-rebuild switch --rollback`, or restore files from the named snapper pre-snapshot (`sudo snapper -c root undochange N..N+1`)
5. Check logs: `journalctl -xe`

### Changes Not Applying

**Solutions:**
1. Did you rebuild? Run `rebuild` (or `sudo nixos-rebuild switch --flake ~/.config/claudeos#$(hostname)`)
2. Check generation changed: `nixos-rebuild list-generations` (generations carry haiku-named labels from `generation-label`)
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

**Symptom:** CLI tools appear among the summon's apps (Super+Space)

**Fix:** Hide via `hideDesktopEntries` (`NoDisplay=true` desktop entries) — user-level list in `home/default.nix` (wins for home-managed packages), system-level list in `modules/desktop/default.nix`.

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

Note: failed user units watched by self-heal (`modules/common/self-heal.nix`) trigger a Claude agent that investigates and may already have opened a fix PR on a `heal/*` branch — check notifications and `gh pr list`. Run `approve` to resume the agent session.

### Recurring Journal Errors

The nightly journal diary (4 AM) triages error-level journal entries against the ledger `docs/known-issues.md`. If a benign error keeps surfacing, add it to the ledger's Benign section — the diary silences known signatures and only reports new actionable ones.

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

#### A saved Wi-Fi network won't connect ("Secrets were required, but not provided")

Wi-Fi runs on iwd under NetworkManager since 2026-11-12. A profile saved before that, or copied from another machine, can fail in two ways. Neither is a wrong password, whatever the message says.

- **The profile is pinned to the old interface name.** iwd calls the card `wlan0`; it used to be `wlp2s0`. A pinned profile matches nothing, so the bar creates a second profile (`<name> 1`) with no password and that one fails.
- **The profile is saved as WPA3-only (`sae`).** NetworkManager's iwd backend rejects it before it reaches the radio. Saving it as `wpa-psk` fixes it, and iwd still uses WPA3 when the access point offers it.

Check, then repair (replace `<name>` with the profile's name):

```bash
nmcli -g connection.interface-name,802-11-wireless-security.key-mgmt connection show "<name>"
```

```bash
nmcli connection modify "<name>" connection.interface-name "" 802-11-wireless-security.key-mgmt wpa-psk 802-11-wireless-security.pmf 0
```

```bash
nmcli connection delete "<name> 1"
```

#### Wi-Fi doesn't come back after undocking

Docked means wired: Wi-Fi is disconnected while Ethernet is up, and `wifi-undock-reconcile.service` reconnects it on undock, boot and resume. To see what it did, and to run it by hand:

```bash
journalctl -b -u wifi-undock-reconcile.service
```

```bash
sudo systemctl restart wifi-undock-reconcile.service
```

A fix to this logic can be tried without undocking: the VM test docks and undocks a simulated laptop (about three minutes, needs `/dev/kvm`).

```bash
nix build .#wifi-undock-test -L
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

1. **Atuin sync disabled** — shell history not synced across machines
2. **VSCode extensions** — Marketplace-managed by design (two-ring); install the Claude extension and others in-app
3. **Chrome extensions** — must install manually (browser limitation)
4. **Morning desk calendar** — requires a one-time interactive `gcalcli init` (OAuth client in sops)

## Getting Help

- [MODULES.md](./MODULES.md) - Module documentation
- [NixOS Wiki](https://wiki.nixos.org)
- [NixOS Discourse](https://discourse.nixos.org)
- Ask the user with AskUserQuestion tool
