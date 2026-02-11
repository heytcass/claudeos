# Disko Configuration

ClaudeOS uses [disko](https://github.com/nix-community/disko) for declarative disk partitioning and formatting. This provides a reproducible installation process and documents our btrfs layout.

## Table of Contents
- [Overview](#overview)
- [Layout](#layout)
- [Installation](#installation)
- [Existing Systems](#existing-systems)
- [Advanced Usage](#advanced-usage)

## Overview

**What is Disko?**
- Declarative disk partitioning for NixOS
- Defines filesystem layout in Nix configuration
- Eliminates manual partitioning during installation
- Ensures consistency across machines

**When to Use:**
- Installing a new ClaudeOS machine (gti, future systems)
- Reinstalling an existing machine
- Documenting the filesystem layout

**When NOT to Use:**
- Already-installed systems (transporter) - use existing hardware-configuration.nix
- Making changes to running systems - disko is for installation only

## Layout

### Standard ClaudeOS Disk Layout

```
/dev/sda
├── /dev/sda1 - 512MB EFI Boot (vfat)
└── /dev/sda2 - Remainder (btrfs with subvolumes)
    ├── @ → / (root)
    ├── @home → /home (user data)
    ├── @nix → /nix (nix store)
    └── @log → /var/log (system logs)
```

### Btrfs Subvolumes

**Why Subvolumes?**
- **@** (root): Easy system rollback via snapshots
- **@home**: User data survives system reinstalls
- **@nix**: Nix store can be snapshotted independently
- **@log**: Logs isolated for cleanup/rotation

### Mount Options

All subvolumes use SSD-optimized btrfs options:
- `noatime` - Don't update access times (reduces writes)
- `compress=zstd:3` - Balanced compression (~30% space savings)
- `ssd` - SSD-aware optimizations
- `discard=async` - Asynchronous TRIM for wear leveling
- `space_cache=v2` - Faster free space tracking

## Installation

### Using Disko for New Installations

#### 1. Boot NixOS Installer

Boot from a NixOS installation USB.

#### 2. Clone Repository

```bash
# From the installer environment
nix-shell -p git
git clone https://github.com/yourusername/claudeos.git
cd claudeos
```

#### 3. Run Disko Installation

```bash
# Install system on /dev/sda (DESTRUCTIVE!)
sudo nix run github:nix-community/disko -- \
  --mode disko \
  --flake .#<hostname>

# Example for gti:
sudo nix run github:nix-community/disko -- \
  --mode disko \
  --flake .#gti
```

This will:
- Partition the disk
- Create btrfs filesystem and subvolumes
- Mount everything under /mnt

#### 4. Generate Hardware Configuration

```bash
# Generate hardware-configuration.nix
nixos-generate-config --no-filesystems --root /mnt

# Copy to the appropriate host directory
cp /mnt/etc/nixos/hardware-configuration.nix hosts/<hostname>/
```

**Why `--no-filesystems`?**
- Disko manages the filesystem configuration
- We don't want nixos-generate-config to override disko's settings
- The generated file will only contain hardware detection (kernel modules, CPU settings)

#### 5. Install NixOS

```bash
# Install using our flake configuration
sudo nixos-install --flake .#<hostname>

# Set root password when prompted
# Reboot when complete
```

### Installation Script

For convenience, use the provided installation script:

```bash
# Make executable
chmod +x install-with-disko.sh

# Run installation (DESTRUCTIVE!)
sudo ./install-with-disko.sh <hostname> [device]

# Example:
sudo ./install-with-disko.sh gti /dev/sda
```

The script:
1. Validates inputs
2. Runs disko to partition/format
3. Generates hardware config (without filesystems)
4. Installs NixOS
5. Prompts for root password

## Existing Systems

### Transporter (Already Installed)

Transporter was installed before disko integration. The disko module is **disabled by default** on existing systems to avoid conflicts.

**Configuration:**
- `disko.enableConfig = false` (default)
- Uses `hosts/transporter/hardware-configuration.nix`
- Same layout as disko, just not managed by disko

**Why Not Enable Disko?**
- System is already installed and working
- hardware-configuration.nix contains the UUIDs of existing partitions
- Enabling disko would conflict with existing configuration
- No benefit to switching on running systems

### Future Systems (gti, etc.)

New installations should use disko:
1. Boot installer
2. Run disko installation
3. Generate hardware-configuration.nix with `--no-filesystems`
4. Install NixOS

## Advanced Usage

### Viewing Disko Configuration

```bash
# Show the generated filesystem configuration
nix eval .#nixosConfigurations.<hostname>.config.disko.devices --json | jq

# Example:
nix eval .#nixosConfigurations.gti.config.disko.devices --json | jq
```

### Manual Disk Preparation

If you want to partition manually but use disko's mount configuration:

```bash
# Format only (don't partition)
sudo nix run github:nix-community/disko -- \
  --mode format \
  --flake .#<hostname>

# Mount only (already formatted)
sudo nix run github:nix-community/disko -- \
  --mode mount \
  --flake .#<hostname>
```

### Custom Disk Device

Override the default `/dev/sda`:

```nix
# In hosts/<hostname>/default.nix
{
  disko.devices.disk.main.device = lib.mkForce "/dev/nvme0n1";
}
```

### Testing Disko Configuration

Validate without actually partitioning:

```bash
# Dry run - show what would happen
sudo nix run github:nix-community/disko -- \
  --mode disko \
  --flake .#<hostname> \
  --dry-run
```

## Btrfs Snapshots

While not automated yet, our subvolume layout enables easy snapshots:

```bash
# Create snapshot before system rebuild
sudo btrfs subvolume snapshot / /.snapshots/root-$(date +%Y%m%d-%H%M%S)

# List snapshots
sudo btrfs subvolume list /

# Restore from snapshot (from rescue environment)
sudo mount /dev/disk/by-label/nixos /mnt
sudo mv /mnt/@ /mnt/@broken
sudo btrfs subvolume snapshot /mnt/.snapshots/root-20260130-120000 /mnt/@
sudo reboot
```

**Future Enhancement:**
- Automatic snapshots before nixos-rebuild
- Snapshot cleanup/rotation
- Integration with systemd-boot menu

## Troubleshooting

### Disko Fails to Partition

**Error:** "Device is busy" or similar

**Solution:**
```bash
# Unmount any existing mounts
sudo umount -R /mnt

# Deactivate LVM/LUKS if present
sudo vgchange -an
sudo cryptsetup close <name>

# Try disko again
```

### Wrong Disk Device

**Error:** "No such device /dev/sda"

**Solution:**
```bash
# List available disks
lsblk

# Override device in configuration or command line
# Option 1: Override in host config (see Custom Disk Device above)
# Option 2: Manually edit modules/common/disko.nix before running
```

### Conflicting Filesystem UUIDs

**Error:** "Filesystem already exists with UUID..."

**Solution:**
```bash
# Wipe existing filesystem signatures
sudo wipefs -a /dev/sda

# Run disko again
```

### Disko vs hardware-configuration.nix Conflicts

**Error:** "fileSystems.'/'.device has conflicting definitions"

**Solution:**

This happens when disko is enabled on an already-installed system.

**Fix 1:** Disable disko (recommended for existing systems):
```nix
# In hosts/<hostname>/default.nix
{
  disko.enableConfig = false;  # Keep hardware-configuration.nix
}
```

**Fix 2:** Remove hardware-configuration.nix filesystems (new installations):
```nix
# Use --no-filesystems when generating:
nixos-generate-config --no-filesystems --root /mnt
```

## References

- [Disko Documentation](https://github.com/nix-community/disko/tree/master/docs)
- [Disko Examples](https://github.com/nix-community/disko/tree/master/example)
- [Btrfs Documentation](https://btrfs.readthedocs.io/)
- [ClaudeOS Hardware Documentation](./HARDWARE.md)

---

*Last updated: 2026-02-02*
