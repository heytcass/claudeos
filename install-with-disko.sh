#!/usr/bin/env bash
#
# ClaudeOS Installation Script with Disko
#
# This script automates NixOS installation using disko for disk partitioning.
#
# Usage:
#   sudo ./install-with-disko.sh <hostname> [device]
#
# Examples:
#   sudo ./install-with-disko.sh gti
#   sudo ./install-with-disko.sh gti /dev/nvme0n1
#
# WARNING: This will DESTROY all data on the target disk!

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

warn() {
    echo -e "${YELLOW}WARNING: $1${NC}" >&2
}

info() {
    echo -e "${GREEN}INFO: $1${NC}"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
fi

# Check arguments
if [[ $# -lt 1 ]] || [[ $# -gt 2 ]]; then
    echo "Usage: $0 <hostname> [device]"
    echo ""
    echo "Examples:"
    echo "  $0 gti"
    echo "  $0 gti /dev/nvme0n1"
    echo ""
    echo "Available hostnames: transporter, gti"
    exit 1
fi

HOSTNAME="$1"
DEVICE="${2:-/dev/sda}"

# Validate hostname
case "$HOSTNAME" in
    transporter|gti)
        ;;
    *)
        error "Invalid hostname. Must be one of: transporter, gti"
        ;;
esac

# Check if device exists
if [[ ! -b "$DEVICE" ]]; then
    error "Device $DEVICE does not exist"
fi

# Get device size
DEVICE_SIZE=$(lsblk -b -d -n -o SIZE "$DEVICE" | numfmt --to=iec)

# Final confirmation
warn "This will DESTROY all data on $DEVICE ($DEVICE_SIZE)"
echo ""
lsblk "$DEVICE"
echo ""
read -p "Type 'yes' to continue: " -r
if [[ ! $REPLY == "yes" ]]; then
    info "Installation cancelled"
    exit 0
fi

info "Starting ClaudeOS installation for $HOSTNAME on $DEVICE"

# Step 1: Unmount any existing mounts
info "Step 1: Cleaning up existing mounts..."
umount -R /mnt 2>/dev/null || true

# Step 2: Override device in disko config if needed
if [[ "$DEVICE" != "/dev/sda" ]]; then
    info "Step 2: Using custom device $DEVICE"
    # We'll pass this to disko
    DISKO_DEVICE_ARG="--argstr device $DEVICE"
else
    DISKO_DEVICE_ARG=""
fi

# Step 3: Run disko to partition and format
info "Step 3: Partitioning and formatting $DEVICE with disko..."
info "This may take a few minutes..."

# Enable disko for installation
export DISKO_ENABLE_CONFIG=true

nix run github:nix-community/disko -- \
    --mode disko \
    --flake ".#$HOSTNAME" \
    $DISKO_DEVICE_ARG

info "Disk partitioning complete"

# Step 4: Verify mounts
info "Step 4: Verifying mounts..."
if ! mountpoint -q /mnt; then
    error "Root filesystem not mounted at /mnt"
fi

df -h | grep /mnt || true

# Step 5: Generate hardware configuration
info "Step 5: Generating hardware configuration..."

# Generate without filesystem info (disko handles that)
nixos-generate-config --no-filesystems --root /mnt

# Backup the generated config
mkdir -p "./hosts/$HOSTNAME.backup"
cp /mnt/etc/nixos/hardware-configuration.nix "./hosts/$HOSTNAME.backup/hardware-configuration.nix"

info "Hardware configuration saved to hosts/$HOSTNAME.backup/"

# Step 6: Install NixOS
info "Step 6: Installing NixOS..."
info "This may take 15-30 minutes depending on internet speed..."

nixos-install --flake ".#$HOSTNAME" --no-root-password

# Step 7: Success
echo ""
info "═══════════════════════════════════════════════════════"
info "ClaudeOS installation complete!"
info "═══════════════════════════════════════════════════════"
echo ""
info "Next steps:"
echo "  1. Set root password:"
echo "     nixos-enter --root /mnt -c 'passwd'"
echo ""
echo "  2. Set user password:"
echo "     nixos-enter --root /mnt -c 'passwd tom'"
echo ""
echo "  3. Review generated hardware config:"
echo "     cat hosts/$HOSTNAME.backup/hardware-configuration.nix"
echo ""
echo "  4. Reboot:"
echo "     reboot"
echo ""
warn "Don't forget to remove the installation media before rebooting!"
