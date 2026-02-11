#!/usr/bin/env bash
#
# ClaudeOS Installation Script with Disko
#
# This script automates NixOS installation using disko for disk partitioning.
# The target disk device is configured per-host in hosts/<hostname>/default.nix
# (via disko.devices.disk.main.device).
#
# Usage:
#   sudo ./install-with-disko.sh <hostname>
#
# Examples:
#   sudo ./install-with-disko.sh transporter
#   sudo ./install-with-disko.sh gti
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
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <hostname>"
    echo ""
    echo "Examples:"
    echo "  $0 transporter"
    echo "  $0 gti"
    echo ""
    echo "Available hostnames: transporter, gti"
    echo ""
    echo "The target disk device is configured per-host in hosts/<hostname>/default.nix"
    echo "(via disko.devices.disk.main.device). Edit that file to change the device."
    exit 1
fi

HOSTNAME="$1"

# Validate hostname
case "$HOSTNAME" in
    transporter|gti)
        ;;
    *)
        error "Invalid hostname. Must be one of: transporter, gti"
        ;;
esac

info "Disk device is configured in hosts/$HOSTNAME/default.nix (disko.devices.disk.main.device)"

# Final confirmation
warn "This will DESTROY all data on the configured disk device for $HOSTNAME"
echo ""
read -p "Type 'yes' to continue: " -r
if [[ ! $REPLY == "yes" ]]; then
    info "Installation cancelled"
    exit 0
fi

info "Starting ClaudeOS installation for $HOSTNAME"

# Step 1: Unmount any existing mounts
info "Step 1: Cleaning up existing mounts..."
umount -R /mnt 2>/dev/null || true

# Step 2: Run disko to partition and format
info "Step 2: Partitioning and formatting with disko..."

# Enable disko for installation
export DISKO_ENABLE_CONFIG=true

nix run github:nix-community/disko -- \
    --mode disko \
    --flake ".#$HOSTNAME"

info "Disk partitioning complete"

# Step 3: Verify mounts
info "Step 3: Verifying mounts..."
if ! mountpoint -q /mnt; then
    error "Root filesystem not mounted at /mnt"
fi

df -h | grep /mnt || true

# Step 4: Generate hardware configuration
info "Step 4: Generating hardware configuration..."

# Generate without filesystem info (disko handles that)
nixos-generate-config --no-filesystems --root /mnt

# Backup the generated config
mkdir -p "./hosts/$HOSTNAME.backup"
cp /mnt/etc/nixos/hardware-configuration.nix "./hosts/$HOSTNAME.backup/hardware-configuration.nix"

info "Hardware configuration saved to hosts/$HOSTNAME.backup/"

# Step 5: Install NixOS
info "Step 5: Installing NixOS..."

nixos-install --flake ".#$HOSTNAME" --no-root-password

# Step 6: Success
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
