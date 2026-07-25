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
- Installing a new ClaudeOS machine (future systems)
- Reinstalling an existing machine
- Documenting the filesystem layout

**When NOT to Use:**
- Making changes to running systems - disko is for installation only

## Layout

### Standard ClaudeOS Disk Layout

There is **no default disk device** — each host pins `disko.devices.disk.main.device` in `hosts/<hostname>/default.nix` (gti uses `/dev/nvme0n1`), so a new host fails evaluation instead of silently targeting the wrong drive.

```
/dev/nvme0n1 (per-host device)
├── p1 - 1GB EFI Boot (vfat)
└── p2 - Remainder (btrfs with subvolumes)
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
git clone https://github.com/heytcass/claudeos.git
cd claudeos
```

#### 3. Run Disko Installation

```bash
# Partition the host's pinned device (DESTRUCTIVE!)
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
sudo ./install-with-disko.sh <hostname>

# Example:
sudo ./install-with-disko.sh gti

# The target disk is not an argument — each host pins its own device in
# hosts/<hostname>/default.nix (disko.devices.disk.main.device).
```

The script:
1. Validates inputs
2. Runs disko to partition/format
3. Generates hardware config (without filesystems)
4. Installs NixOS
5. Prompts for root password

## Existing Systems

### gti (Already Installed)

gti was installed with disko, and `disko.enableConfig` defaults to `true` — disko generates the `fileSystems` entries declaratively. Its `hardware-configuration.nix` was generated with `--no-filesystems` and contains only hardware detection (kernel modules, CPU config).

If a system is ever installed *without* disko, set `disko.enableConfig = false;` in its host config to avoid conflicting filesystem definitions.

### Future Systems

New installations should use disko:
1. Add the host to `flake.nix` and pin its disk device in `hosts/<hostname>/default.nix`
2. Boot installer and run disko installation
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

### Disk Device (Required Per Host)

`modules/common/disko.nix` deliberately sets no default device — every host must pin its own:

```nix
# In hosts/<hostname>/default.nix
{
  disko.devices.disk.main.device = "/dev/nvme0n1";
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

Snapshots are automated via snapper (`modules/common/snapshots.nix`): hourly timeline snapshots plus pre/post pairs around the `rebuild` fish function, with number cleanup. Manual snapshots remain available:

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
- Integration with systemd-boot menu

(Automatic pre-rebuild snapshots and cleanup/rotation are already handled by snapper.)

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

**Error:** "No such device /dev/nvme0n1" (or evaluation fails because no device is set)

**Solution:**
```bash
# List available disks
lsblk

# Set the device in the host config (see Disk Device above) —
# modules/common/disko.nix intentionally has no default to edit
```

### Conflicting Filesystem UUIDs

**Error:** "Filesystem already exists with UUID..."

**Solution:**
```bash
# Wipe existing filesystem signatures (use your target device)
sudo wipefs -a /dev/nvme0n1

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

*Last updated: 2026-06-11*
