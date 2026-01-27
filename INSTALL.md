# NixOS Installation Quick Guide

**This is a quick reference for installing NixOS on transporter. See docs/DEPLOYMENT.md for full details.**

## Prerequisites

- NixOS minimal ISO downloaded
- USB drive with ISO burned
- Target machine (transporter) ready
- Network connection available

## Installation Steps

### 1. Boot NixOS Installer

Boot from USB, select "NixOS installer"

### 2. Partition Disk

```bash
# Identify disk
lsblk

# Set disk variable (adjust for your system)
DISK=/dev/sda  # or /dev/nvme0n1

# Create partitions
parted $DISK -- mklabel gpt
parted $DISK -- mkpart ESP fat32 1MiB 512MiB
parted $DISK -- set 1 esp on
parted $DISK -- mkpart primary 512MiB 100%

# Format
mkfs.fat -F 32 -n boot ${DISK}1
mkfs.ext4 -L nixos ${DISK}2
```

### 3. Mount

```bash
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot
```

### 4. Setup Repository

```bash
# Get git
nix-shell -p git

# Clone repo to /mnt/etc/nixos
cd /mnt/etc
rm -rf nixos
git clone <your-repo-url> nixos
cd nixos

# Generate hardware config
nixos-generate-config --root /mnt

# Copy hardware config to repo
cp /mnt/etc/nixos-generated/hardware-configuration.nix \
   hosts/transporter/hardware-configuration.nix

# Review and commit hardware config
# (You'll push this after install)
```

### 5. Install

```bash
# Install NixOS
nixos-install --flake .#transporter

# Set passwords when prompted
# Root password first, then:
```

After install completes:
```bash
# Chroot to set user password
nixos-enter --root /mnt
passwd tom
exit

# Reboot
reboot
```

### 6. Post-Install

After reboot and login:

```bash
# Commit and push hardware config
cd /etc/nixos
git add hosts/transporter/hardware-configuration.nix
git commit -m "feat(transporter): add hardware configuration"
git push origin main

# Test SSH from Ubuntu
# From your Ubuntu machine:
ssh tom@transporter
```

## Quick Verification

On transporter after install:

```bash
# Check hostname
hostname
# Should output: transporter

# Check Nix version
nix --version

# Check flake
cd /etc/nixos
nix flake check

# Check network
ping google.com

# Check user
whoami
# Should output: tom

# Check shell
echo $SHELL
# Should output: /run/current-system/sw/bin/fish
```

## Troubleshooting

### Can't boot after install
- Select older generation from boot menu
- Or boot from USB and check /mnt/boot

### Network not working
- Check NetworkManager: `systemctl status NetworkManager`
- Use nmtui to configure: `nmtui`

### SSH not working
- Check firewall: `sudo systemctl status firewall`
- Check SSH: `sudo systemctl status sshd`
- Try from Ubuntu: `ssh -v tom@transporter`

## Next Steps

1. Verify installation checklist from docs/DEPLOYMENT.md
2. Update docs/IMPLEMENTATION_STATUS.md
3. Proceed to Phase 2 (Desktop Environment)

## Repository Location on Target

- **Configuration:** `/etc/nixos`
- **This is a git repo** - all changes via git pull
- **Never edit directly** on target machine
- **Always edit on Ubuntu**, commit, push, then pull on target

## Useful Commands

```bash
# Rebuild system
sudo nixos-rebuild switch --flake .#transporter

# List generations
sudo nixos-rebuild list-generations

# Rollback
sudo nixos-rebuild switch --rollback

# Update flake inputs
nix flake update

# Check configuration
nix flake check
```
