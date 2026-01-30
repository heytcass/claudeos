# ClaudeOS Installation Guide

Quick installation guide for ClaudeOS using disko for automated disk partitioning.

## Two Installation Methods

### Method 1: Automated with Disko (Recommended)

**Best for:** New installations (gti, future systems)

See full instructions below or in [docs/DISKO.md](docs/DISKO.md)

### Method 2: Manual Installation (Legacy)

**For reference only** - Original transporter installation used manual partitioning.

See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for the manual process.

---

## Automated Installation with Disko

### Prerequisites

- NixOS installation USB
- Target machine with UEFI support
- Internet connection
- Git installed in installer environment

### Quick Install Steps

#### 1. Boot Installer

Boot from NixOS installation USB (UEFI mode).

#### 2. Get ClaudeOS

```bash
# Enter nix-shell with git
nix-shell -p git

# Clone repository
git clone https://github.com/yourusername/claudeos.git
cd claudeos
```

#### 3. Run Installation

```bash
# Make script executable
chmod +x install-with-disko.sh

# Install (DESTRUCTIVE! Wipes target disk)
sudo ./install-with-disko.sh <hostname> [device]

# Examples:
sudo ./install-with-disko.sh gti              # Install on /dev/sda
sudo ./install-with-disko.sh gti /dev/nvme0n1 # Install on NVMe
```

The script will:
- Prompt for confirmation (shows disk size and layout)
- Partition and format the disk with disko
- Install NixOS with your configuration
- Generate hardware-configuration.nix
- Prepare the system for first boot

#### 4. Set Passwords

```bash
# Set root password
nixos-enter --root /mnt -c 'passwd'

# Set user password
nixos-enter --root /mnt -c 'passwd tom'
```

#### 5. Reboot

```bash
reboot
```

Remove installation USB and boot into ClaudeOS!

### What Gets Installed

#### Disk Layout

```
/dev/sda (or your chosen device)
├── 512MB EFI Boot Partition (vfat)
└── Remainder: btrfs with subvolumes
    ├── @ → /
    ├── @home → /home
    ├── @nix → /nix
    └── @log → /var/log
```

#### Filesystem Features

- **btrfs compression:** zstd:3 (~30% space savings)
- **SSD optimized:** noatime, discard=async
- **Snapshot ready:** Subvolume layout supports snapshots
- **Fast:** space_cache=v2 for better performance

#### System Configuration

Based on hostname (gti, transporter, etc.):
- NixOS unstable
- GNOME 49 desktop
- Wayland + Pipewire
- Fish shell
- Home Manager
- Claude Code CLI
- Development tools (git, vim, VSCode)

See [docs/MODULES.md](docs/MODULES.md) for complete feature list.

## Post-Installation

### First Boot

1. Log in with user `tom` (password set during installation)
2. Connect to WiFi (NetworkManager)
3. System is ready to use!

### Configuration Location

```bash
# Clone configuration to home directory
cd ~/.config
git clone https://github.com/yourusername/claudeos.git
cd claudeos

# Update system
sudo nixos-rebuild switch --flake .#$(hostname)

# Or use the convenience alias:
rebuild
```

### Customize

Edit configuration in `~/.config/claudeos/`:
- User settings: `home/` directory
- System modules: `modules/` directory
- Host-specific: `hosts/<hostname>/`

See [docs/WORKFLOW.md](docs/WORKFLOW.md) for development workflow.

## Verification

After first boot, verify the installation:

```bash
# Check hostname
hostname  # Should match what you installed (gti, etc.)

# Check shell
echo $SHELL  # Should be /run/current-system/sw/bin/fish

# Check keyboard layout
# Try typing - should be US Colemak

# Check network
ping -c 2 google.com

# Check btrfs
sudo btrfs filesystem show
sudo btrfs subvolume list /

# Check configuration
cd ~/.config/claudeos
nix flake check
```

**All checks passing?** ✅ Installation complete!

## Troubleshooting

### Installation Fails

**Device busy:**
```bash
sudo umount -R /mnt
# Try installation again
```

**Wrong device:**
```bash
# List available disks
lsblk
# Use correct device in install command
```

**Partitioning fails:**
```bash
# Wipe existing signatures
sudo wipefs -a /dev/sda
# Try again
```

### Can't Boot

1. Boot from USB again
2. Mount and chroot:
```bash
sudo mount /dev/sda2 /mnt -o subvol=@
sudo mount /dev/sda1 /mnt/boot
nixos-enter --root /mnt
# Fix configuration if needed
nixos-rebuild switch
```

### Network Issues

```bash
# Check NetworkManager
systemctl status NetworkManager

# Use nmtui to configure
nmtui
```

## Advanced Installation

For manual installation, customization, or troubleshooting:
- [docs/DISKO.md](docs/DISKO.md) - Detailed disko documentation
- [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) - Manual deployment procedures
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Common issues

## Useful Commands

```bash
# Rebuild system
rebuild  # Alias for: sudo nixos-rebuild switch --flake ~/.config/claudeos#$(hostname)

# List generations
sudo nixos-rebuild list-generations

# Rollback to previous generation
sudo nixos-rebuild switch --rollback

# Update packages
cd ~/.config/claudeos
nix flake update
rebuild

# Garbage collect old generations
nix-collect-garbage --delete-older-than 30d
```

## Getting Help

- Issues: https://github.com/yourusername/claudeos/issues
- Documentation: [docs/](docs/)
- CLAUDE.md: Project-specific instructions for Claude Code

---

**WARNING:** Installation is DESTRUCTIVE and will erase the target disk. Back up important data first!
