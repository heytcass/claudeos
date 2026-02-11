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

# Enable experimental Nix features needed for flakes and nix commands
export NIX_CONFIG="experimental-features = nix-command flakes"

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

# Cleanup function for error handling
cleanup_on_error() {
    if [[ $? -ne 0 ]]; then
        warn "Installation failed! Cleaning up..."
        umount -R /mnt 2>/dev/null || true
    fi
}

# Set up error cleanup trap
trap cleanup_on_error EXIT

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
fi

# Get the original user (who invoked sudo)
ORIGINAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "")}"
ORIGINAL_UID="${SUDO_UID:-$(id -u "$ORIGINAL_USER" 2>/dev/null || echo "")}"
ORIGINAL_GID="${SUDO_GID:-$(id -g "$ORIGINAL_USER" 2>/dev/null || echo "")}"

if [[ -z "$ORIGINAL_USER" || -z "$ORIGINAL_UID" ]]; then
    error "Cannot determine original user. Please run with sudo."
fi

# Check for required commands
REQUIRED_COMMANDS=("nix" "nixos-install" "nixos-generate-config" "git" "mountpoint")
for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        error "Required command '$cmd' not found. Are you running on NixOS installation media?"
    fi
done

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

# Find git repository root (handle being run from subdirectories)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -d "$SCRIPT_DIR/.git" ]]; then
    # Try to find git root
    GIT_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null || echo "")"
    if [[ -z "$GIT_ROOT" ]]; then
        error "Not in a git repository. Please run from the claudeos repository."
    fi
    info "Changing to repository root: $GIT_ROOT"
    cd "$GIT_ROOT"
else
    cd "$SCRIPT_DIR"
fi

REPO_ROOT="$(pwd)"

# Validate host directory exists
if [[ ! -d "$REPO_ROOT/hosts/$HOSTNAME" ]]; then
    error "Host directory '$REPO_ROOT/hosts/$HOSTNAME' does not exist"
fi

# Check internet connectivity
info "Checking internet connectivity..."
if ! ping -c 1 -W 2 github.com &>/dev/null && ! ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
    error "No internet connectivity. Please check your network connection."
fi

# Validate flake configuration
info "Validating flake configuration..."
if ! nix flake show --json 2>/dev/null | grep -q "\"nixosConfigurations\".*\"$HOSTNAME\""; then
    error "Host '$HOSTNAME' not found in flake. Run 'nix flake show' to see available configurations."
fi

# Extract username from flake (check home-manager configuration)
info "Detecting username from flake configuration..."
USERNAME=$(nix eval --raw ".#nixosConfigurations.$HOSTNAME.config.users.users" --apply 'users: builtins.head (builtins.filter (u: users.${u}.isNormalUser or false) (builtins.attrNames users))' 2>/dev/null || echo "tom")

if [[ -z "$USERNAME" ]]; then
    warn "Could not detect username from flake, using default: tom"
    USERNAME="tom"
else
    info "Detected username: $USERNAME"
fi

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

# Try to use nixpkgs disko if available (faster), fallback to GitHub
if nix-env -qa 2>/dev/null | grep -q "^disko-"; then
    info "Using disko from nixpkgs..."
    DISKO_CMD="nix run nixpkgs#disko"
else
    info "Downloading disko from GitHub..."
    DISKO_CMD="nix run github:nix-community/disko"
fi

$DISKO_CMD -- \
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

# Backup the previous placeholder config (create directory if needed)
BACKUP_DIR="$REPO_ROOT/hosts/$HOSTNAME.backup"
mkdir -p "$BACKUP_DIR"
chown "$ORIGINAL_UID:$ORIGINAL_GID" "$BACKUP_DIR"

if [[ -f "$REPO_ROOT/hosts/$HOSTNAME/hardware-configuration.nix" ]]; then
    cp "$REPO_ROOT/hosts/$HOSTNAME/hardware-configuration.nix" "$BACKUP_DIR/hardware-configuration.nix.old"
    chown "$ORIGINAL_UID:$ORIGINAL_GID" "$BACKUP_DIR/hardware-configuration.nix.old"
fi

# Copy generated config into the flake so nixos-install uses real hardware values
cp /mnt/etc/nixos/hardware-configuration.nix "$REPO_ROOT/hosts/$HOSTNAME/hardware-configuration.nix"
chown "$ORIGINAL_UID:$ORIGINAL_GID" "$REPO_ROOT/hosts/$HOSTNAME/hardware-configuration.nix"
info "Hardware configuration installed to hosts/$HOSTNAME/hardware-configuration.nix"

# Step 5: Install NixOS
info "Step 5: Installing NixOS..."

nixos-install --flake ".#$HOSTNAME" --no-root-password

# Step 6: Copy repository to installed system
info "Step 6: Installing configuration repository..."

# Get user UID/GID from installed system
USER_UID=$(nixos-enter --root /mnt -c "id -u $USERNAME" 2>/dev/null || echo "1000")
USER_GID=$(nixos-enter --root /mnt -c "id -g $USERNAME" 2>/dev/null || echo "100")

# Create .config directory
mkdir -p "/mnt/home/$USERNAME/.config"
chown "$USER_UID:$USER_GID" "/mnt/home/$USERNAME/.config"

# Copy entire repository including .git
info "Copying repository to /home/$USERNAME/.config/claudeos..."
cp -r "$REPO_ROOT" "/mnt/home/$USERNAME/.config/claudeos"

# Set ownership recursively
chown -R "$USER_UID:$USER_GID" "/mnt/home/$USERNAME/.config/claudeos"

info "Repository installed at ~/.config/claudeos"

# Step 7: Success
echo ""
info "═══════════════════════════════════════════════════════"
info "ClaudeOS installation complete!"
info "═══════════════════════════════════════════════════════"
echo ""
info "Next steps:"
echo "  1. Set user password:"
echo "     sudo nixos-enter --root /mnt -c 'passwd $USERNAME'"
echo ""
echo "  2. Reboot:"
echo "     reboot"
echo ""
echo "  3. After reboot, the configuration is at ~/.config/claudeos"
echo "     - Commit the generated hardware config:"
echo "       cd ~/.config/claudeos"
echo "       git add hosts/$HOSTNAME/hardware-configuration.nix"
echo "       git commit -m 'feat($HOSTNAME): add hardware-configuration.nix from install'"
echo "       git push"
echo ""
echo "     - To update the system later:"
echo "       cd ~/.config/claudeos"
echo "       git pull"
echo "       sudo nixos-rebuild switch --flake .#$HOSTNAME"
echo ""
warn "Don't forget to remove the installation media before rebooting!"

# Disable error trap on successful completion
trap - EXIT
