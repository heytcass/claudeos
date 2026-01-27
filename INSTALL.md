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
sudo parted $DISK -- mklabel gpt
sudo parted $DISK -- mkpart ESP fat32 1MiB 512MiB
sudo parted $DISK -- set 1 esp on
sudo parted $DISK -- mkpart primary 512MiB 100%

# Format boot partition
sudo mkfs.fat -F 32 -n boot ${DISK}1

# Format root with btrfs (recommended)
sudo mkfs.btrfs -f -L nixos ${DISK}2

# Or use ext4 (simpler, but no snapshots/compression):
# sudo mkfs.ext4 -L nixos ${DISK}2
```

### 3. Setup Btrfs Subvolumes (if using btrfs)

**Why btrfs?** Snapshots, compression (saves ~30% disk space), subvolumes for flexible management.

```bash
# Mount temporarily to create subvolumes
sudo mount /dev/sda2 /mnt

# Create subvolumes
sudo btrfs subvolume create /mnt/@           # root
sudo btrfs subvolume create /mnt/@home       # home
sudo btrfs subvolume create /mnt/@nix        # nix store
sudo btrfs subvolume create /mnt/@log        # logs

# Verify
sudo btrfs subvolume list /mnt

# Unmount
sudo umount /mnt
```

### 4. Mount Filesystems

**For btrfs:**

```bash
# Mount options (compression + noatime)
BTRFS_OPTS="noatime,compress=zstd,space_cache=v2"

# Mount root subvolume
sudo mount -o $BTRFS_OPTS,subvol=@ /dev/sda2 /mnt

# Create mount points
sudo mkdir -p /mnt/{boot,home,nix,var/log}

# Mount other subvolumes
sudo mount -o $BTRFS_OPTS,subvol=@home /dev/sda2 /mnt/home
sudo mount -o $BTRFS_OPTS,subvol=@nix /dev/sda2 /mnt/nix
sudo mkdir -p /mnt/var
sudo mount -o $BTRFS_OPTS,subvol=@log /dev/sda2 /mnt/var/log

# Mount boot
sudo mount /dev/sda1 /mnt/boot

# Verify
mount | grep /mnt
```

**For ext4 (if you chose ext4 instead):**

```bash
sudo mount /dev/disk/by-label/nixos /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/disk/by-label/boot /mnt/boot
```

### 5. Setup Repository

```bash
# Get git
nix-shell -p git

# Transfer config from Ubuntu (if not already done)
# From Ubuntu: scp -r /home/tom/projects/claudeos nixos@<IP>:/tmp/claudeos

# Move to mounted filesystem
sudo mkdir -p /mnt/home/tom/.config
sudo mv /tmp/claudeos /mnt/home/tom/.config/claudeos
cd /mnt/home/tom/.config/claudeos

# Generate hardware config (detects btrfs subvolumes)
sudo nixos-generate-config --root /mnt

# Copy hardware config to repo
sudo cp /mnt/etc/nixos/hardware-configuration.nix \
   hosts/transporter/hardware-configuration.nix

# Configure git and commit
git config user.email "tom@example.com"
git config user.name "Tom"
git add hosts/transporter/hardware-configuration.nix
git commit -m "feat(transporter): add btrfs hardware configuration"
```

### 6. Install

```bash
# Install NixOS (takes a few minutes)
sudo nixos-install --flake .#transporter

# Set root password when prompted
```

After install completes:
```bash
# Chroot to set user password
sudo nixos-enter --root /mnt
passwd tom
exit

# Reboot
sudo reboot
```

Remove USB drive when rebooting.

### 7. Post-Install - Fix Permissions

After first SSH login as tom:

```bash
# Fix home directory ownership (created by sudo during install)
sudo chown -R tom:users /home/tom

# Exit and reconnect
exit
```

SSH back in and verify everything works.

### 8. Copy Hardware Config Back to Ubuntu

From your **Ubuntu machine**:

```bash
# Copy hardware config from transporter
scp tom@10.0.10.205:~/.config/claudeos/hosts/transporter/hardware-configuration.nix \
    /home/tom/projects/claudeos/hosts/transporter/

# Commit it
cd /home/tom/projects/claudeos
git add hosts/transporter/hardware-configuration.nix
git commit -m "feat(transporter): add btrfs hardware configuration"
```

## Phase 1 Verification

On transporter after install and permission fix:

```bash
# Check hostname
hostname
# Should output: transporter

# Check user and shell
whoami
echo $SHELL
# Should be: tom, /run/current-system/sw/bin/fish

# Test keyboard - should be Colemak layout
# Try typing - layout should be Colemak

# Check network
ping -c 2 google.com

# Check sudo works
sudo echo "sudo works"

# Check basic packages
git --version
vim --version
htop --version

# Check config location
cd ~/.config/claudeos
pwd
ls -la

# Check git status
git status

# Verify flake
nix flake check

# Check btrfs (if using btrfs)
sudo btrfs filesystem show
sudo btrfs subvolume list /
```

**Phase 1 Complete!** ✅ All checks should pass.

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

- **Configuration:** `~/.config/claudeos` (`/home/tom/.config/claudeos`)
- **This is a git repo** - all changes via git pull
- **No sudo needed to edit** - it's in your home directory
- **Best practice: Edit on Ubuntu**, commit, push, then pull on target
- **Can edit directly if needed** - just commit and push back to stay in sync

## Useful Commands

```bash
# Rebuild system (from ~/.config/claudeos)
sudo nixos-rebuild switch --flake ~/.config/claudeos#transporter

# Or add this alias to your fish config:
alias nixos-rebuild-switch='sudo nixos-rebuild switch --flake ~/.config/claudeos#(hostname)'

# List generations
sudo nixos-rebuild list-generations

# Rollback
sudo nixos-rebuild switch --rollback

# Update flake inputs
nix flake update

# Check configuration
nix flake check
```
