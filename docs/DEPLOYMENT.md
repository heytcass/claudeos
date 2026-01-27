# Deployment Guide

**This guide covers deploying ClaudeOS configuration to NixOS machines.**

## Prerequisites

### Target Machine Requirements
- Fresh NixOS minimal install
- UEFI boot mode (for systemd-boot)
- Network connectivity
- SSH access configured

### Development Machine Requirements
- Git configured
- SSH key added to target machine (optional for initial setup)
- This repository cloned to `/home/tom/projects/claudeos`

## Initial NixOS Installation

### 1. Boot NixOS Installer

Download NixOS minimal ISO and boot target machine.

### 2. Partition Disk

**For UEFI systems (our configuration):**

```bash
# Identify disk (usually /dev/sda or /dev/nvme0n1)
lsblk

# Example for /dev/sda - adjust for your disk
DISK=/dev/sda

# Create GPT partition table
parted $DISK -- mklabel gpt

# Create EFI boot partition (512MB)
parted $DISK -- mkpart ESP fat32 1MiB 512MiB
parted $DISK -- set 1 esp on

# Create root partition (rest of disk)
parted $DISK -- mkpart primary 512MiB 100%

# Format partitions
mkfs.fat -F 32 -n boot ${DISK}1
mkfs.ext4 -L nixos ${DISK}2

# For swap (optional, 8GB example):
# parted $DISK -- mkpart primary linux-swap 512MiB 8.5GiB
# parted $DISK -- mkpart primary 8.5GiB 100%
# mkswap -L swap ${DISK}2
# mkfs.ext4 -L nixos ${DISK}3
```

### 3. Mount Filesystems

```bash
# Mount root
mount /dev/disk/by-label/nixos /mnt

# Create and mount boot
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot

# If using swap:
# swapon /dev/disk/by-label/swap
```

### 4. Generate Hardware Configuration

```bash
# Generate config
nixos-generate-config --root /mnt

# The installer creates:
# /mnt/etc/nixos/configuration.nix (we'll replace)
# /mnt/etc/nixos/hardware-configuration.nix (we'll copy)
```

### 5. Clone Repository

```bash
# Install git in installer environment
nix-shell -p git

# Clone repo to /mnt/etc/nixos
cd /mnt/etc
rm -rf nixos  # Remove default config
git clone <repo-url> nixos
cd nixos

# Copy generated hardware config to appropriate host
cp /mnt/etc/nixos-generated/hardware-configuration.nix \
   hosts/transporter/hardware-configuration.nix  # or hosts/gti/

# Commit hardware config
git add hosts/transporter/hardware-configuration.nix
git commit -m "feat(transporter): add hardware configuration"
git push
```

### 6. Initial Install

```bash
# Still in /mnt/etc/nixos on installer
nixos-install --flake .#transporter  # or .#gti

# Set root password when prompted
# Set user password
nixos-install --root /mnt --no-root-passwd
passwd tom  # Will prompt for password

# Reboot
reboot
```

## Subsequent Deployments

### Method 1: Manual on Target (Recommended)

```bash
# SSH to target
ssh tom@transporter  # or gti

# Navigate to config directory
cd /etc/nixos

# Pull latest changes
git pull origin main

# Apply configuration
sudo nixos-rebuild switch --flake .#transporter

# Reboot if kernel/boot changed (usually not needed)
# sudo reboot
```

### Method 2: Remote from Ubuntu

```bash
# From development machine
nixos-rebuild switch --flake .#transporter \
  --target-host tom@transporter \
  --use-remote-sudo

# This requires:
# - SSH key access
# - Passwordless sudo or TTY sudo configured
```

### Method 3: Deployer Agent

```bash
# Use deployer agent (not yet implemented in Phase 1)
@deployer-agent deploy transporter with message "feat: add module"
```

## Rollback

If something breaks:

```bash
# On target machine
# List generations
sudo nixos-rebuild list-generations

# Rollback to previous generation
sudo nixos-rebuild switch --rollback

# Or boot specific generation
sudo nixos-rebuild switch --switch-generation <number>
```

Generations are also available in boot menu (systemd-boot).

## Deployment Workflow

### Full Workflow from Ubuntu

1. **Make changes** to configuration
2. **Validate** on Ubuntu:
   ```bash
   cd /home/tom/projects/claudeos
   nix flake check
   ```
3. **Commit and push**:
   ```bash
   git add .
   git commit -m "feat: description"
   git push origin main
   ```
4. **Deploy to target**:
   ```bash
   ssh transporter
   cd /etc/nixos
   git pull
   sudo nixos-rebuild switch --flake .#transporter
   exit
   ```
5. **Test** functionality
6. **If successful**, deploy to next machine (gti)

### Testing Strategy

- **Always test on transporter first**
- **Verify critical functionality** before deploying to gti
- **Keep working generation** - don't delete until new one verified
- **Document issues** in TROUBLESHOOTING.md

## Common Deployment Issues

### SSH Access Issues

```bash
# From Ubuntu, test SSH
ssh tom@transporter echo "ok"

# If fails, check:
# - Is machine on network? ping transporter
# - Is SSH service running? ssh root@transporter systemctl status sshd
# - Correct hostname? Check /etc/hosts or DNS
```

### Disk Space Issues

```bash
# Check disk space
df -h

# Clean old generations
sudo nix-collect-garbage -d

# Or keep last N generations
sudo nix-collect-garbage --delete-older-than 30d
```

### Build Fails on Target

```bash
# Check error message carefully
# Common issues:
# - Syntax error (fix in dev, push, pull)
# - Missing import (check file paths)
# - Network issue (check internet connection)

# Rollback to working generation
sudo nixos-rebuild switch --rollback
```

### Hardware Configuration Issues

If hardware config is wrong:

```bash
# Regenerate (on target)
sudo nixos-generate-config

# Copy new hardware-configuration.nix to repo
# Commit and redeploy
```

## Post-Deployment Verification

### Phase 1 Checklist
- [ ] Machine boots successfully
- [ ] SSH access works
- [ ] User can login
- [ ] Network connectivity works
- [ ] `sudo` works for tom
- [ ] Basic commands work (git, vim, htop)

### Phase 2 Checklist
- [ ] GNOME loads
- [ ] Wayland session active (`echo $XDG_SESSION_TYPE`)
- [ ] Audio works (play test sound)
- [ ] Display settings correct

### Phase 3 Checklist
- [ ] WezTerm launches
- [ ] Fish is default shell
- [ ] CLI tools work (eza, bat, zoxide, atuin, yazi)
- [ ] Chrome launches
- [ ] Git configured correctly

### Phase 4 Checklist
- [ ] Claude Code CLI works
- [ ] Claude Desktop launches
- [ ] Claude in Chrome extension works
- [ ] VSCode with Claude extension works

### Phase 5 Checklist
- [ ] Secrets decrypted correctly
- [ ] Applications use secrets
- [ ] Both machines (transporter, gti) working identically

## Security Considerations

### Initial Setup
- Set strong passwords for root and user
- Configure SSH key authentication
- Disable password SSH after key setup

### Secrets
- Never commit unencrypted secrets
- Use sops-nix for all sensitive data (Phase 5)
- Rotate keys regularly

### Updates
- Update flake inputs monthly: `nix flake update`
- Apply security updates promptly
- Test updates on transporter before gti

## Backup Strategy

### Configuration Backup
- Configuration is in git - push regularly
- Keep multiple remotes (GitHub, GitLab, local)

### Hardware Configuration Backup
- Hardware configs are machine-specific
- Back up before hardware changes
- Store separately from main config

### User Data Backup
- Home-manager manages dotfiles
- User data (/home) should be backed up separately
- Consider NixOS impermanence for stateless system (future enhancement)

## Next Steps After Deployment

1. Verify all checklist items for current phase
2. Update IMPLEMENTATION_STATUS.md
3. Document any issues in TROUBLESHOOTING.md
4. Proceed to next phase or stabilize current phase
5. Consider deploying to second machine (gti) once first is stable
