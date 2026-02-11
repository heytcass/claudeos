# Hardware Documentation

Complete documentation for ClaudeOS hardware configurations, issues, and optimizations.

**Table of Contents:**
- [Machines](#machines)
- [Hardware-Specific Notes](#hardware-specific-notes)
- [Common Issues](#common-issues)
- [Performance Tuning](#performance-tuning)
- [Power Management](#power-management)

## Machines

### transporter - Dell Latitude 7280

**Hardware Profile:** `nixos-hardware.nixosModules.dell-latitude-7280`

**Specs:**
- CPU: Intel (with kvm-intel support)
- Storage: 238.5GB SSD (btrfs)
- Kernel Modules: xhci_pci, ahci, usb_storage, sd_mod, rtsx_pci_sdmmc
- Network: IPv6 capable

**Filesystem Configuration:**
- **Format:** btrfs with zstd compression
- **Label:** nixos
- **UUID:** 3c51bbee-4eb6-427e-aafb-3a40051aba87
- **Mount Options:** noatime,compress=zstd:3,ssd,discard=async,space_cache=v2
- **Subvolumes:**
  - `@` - root (subvolid=256, mounted at /)
  - `@home` - home directories (subvolid=257, mounted at /home)
  - `@nix` - nix store (subvolid=258, mounted at /nix)
  - `@log` - logs (subvolid=259, mounted at /var/log)
- **Boot:** 511MB vfat partition on /dev/sda1

**Status:** ✅ Deployed and operational

**Installation Date:** 2026-01-27

**Known Issues:**
- **Resolved:** Home directory ownership (fixed post-install with `sudo chown -R tom:users /home/tom`)

**Working Features:**
- systemd-boot bootloader
- Fish shell
- US Colemak keyboard layout
- NetworkManager
- SSH access
- Git, vim, htop
- Nix flakes
- COSMIC desktop
- Ghostty terminal

### gti - Dell XPS 13 9370

**Hardware Profile:** `nixos-hardware.nixosModules.dell-xps-13-9370`

**Status:** Ready for deployment

**Planned Configuration:**
- Will use same btrfs subvolume layout as transporter
- Same module configuration as transporter
- Dell XPS-specific optimizations from nixos-hardware

**Specs:** (To be documented after deployment)
- CPU: Intel (model TBD)
- RAM: TBD
- Storage: TBD (SSD)
- Display: 13" (resolution TBD)
- Network: WiFi + optional USB-C ethernet

**Known Issues:** (To be discovered during deployment)

## Hardware-Specific Notes

### Dell Latitude 7280

**Btrfs Benefits on This Hardware:**
- SSD optimizations automatically detected (ssd,discard=async)
- zstd compression saves ~30% disk space on 238.5GB drive
- Instant snapshots available (not yet configured)
- Subvolumes allow flexible backup/restore strategies

**Performance Notes:**
- SSD detected and optimized automatically
- Compression level 3 (zstd:3) provides good balance of speed/compression

**Recommended Tweaks:**
- Consider btrfs snapshots before/after system rebuilds
- May want to adjust swappiness for SSD longevity

### Dell XPS 13 9370

_To be documented after deployment_

**Expected Optimizations:**
- Intel graphics acceleration
- WiFi power management
- Touchpad configuration
- HiDPI display scaling (if applicable)
- Thunderbolt 3 support

---

## Common Issues

### Post-Installation

**Home Directory Ownership:**
- **Symptom:** Permission errors in home directory after installation
- **Cause:** NixOS installation creates home directory with root ownership
- **Fix:** `sudo chown -R tom:users /home/tom`
- **Status:** Fixed on transporter, documented for gti

---

## Performance Tuning

### Btrfs Optimization

**Current Configuration:**
- Compression: zstd level 3 (balance of speed/compression)
- Mount options: `noatime,compress=zstd:3,ssd,discard=async,space_cache=v2`
- Space savings: ~30% from compression

**Optimization Options:**
```bash
# Check compression ratio
sudo compsize /

# Balance filesystem (if needed)
sudo btrfs balance start -dusage=50 -musage=50 /

# Scrub for data integrity
sudo btrfs scrub start /
sudo btrfs scrub status /
```

### Nix Store Optimization

**Automatic Optimization:**
- Configured in modules/common/nix.nix
- Runs on every rebuild: `nix.settings.auto-optimise-store = true`
- Deduplicates files in /nix/store

**Manual Optimization:**
```bash
# Optimize store (already automatic)
nix store optimise

# Check store size
du -sh /nix/store

# Garbage collect old generations
nix-collect-garbage --delete-older-than 30d
```

### Intel Thermal Management

**Thermald Configuration:**
- Enabled in modules/common/system.nix
- Prevents thermal throttling on Intel CPUs
- Automatic thermal policy management

---

## Power Management

### Battery Optimization (Laptops)

**Bluetooth:**
- Disabled on boot for battery saving (modules/desktop/audio.nix)
- `hardware.bluetooth.powerOnBoot = false`
- Enable manually when needed

**Network:**
- NetworkManager-wait-online disabled (faster boot, less power)
- WiFi power management handled by NetworkManager

**Future Enhancements:**
- TLP or auto-cpufreq for advanced power management
- Battery threshold configuration (Dell specific)
- Display brightness auto-adjustment

### SSD Longevity

**Current Configuration:**
- Btrfs with `discard=async` for TRIM support
- `noatime` reduces write operations
- Automatic TRIM handled by systemd

**Additional Options:**
```bash
# Check TRIM support
sudo fstrim -v /

# Adjust swappiness (reduce SSD writes)
sudo sysctl vm.swappiness=10
```

---

## Firmware and Updates

### Firmware Updates (fwupd)

**Configuration:**
- Enabled in modules/common/system.nix
- Automatic firmware update checking

**Usage:**
```bash
# Check for firmware updates
fwupdmgr get-devices
fwupdmgr get-updates

# Apply firmware updates
fwupdmgr update

# View update history
fwupdmgr get-history
```

### System Updates

**NixOS Updates:**
```bash
# Update flake inputs
cd ~/.config/claudeos
nix flake update

# Rebuild with updated packages
sudo nixos-rebuild switch --flake .#$(hostname)

# Or use alias
rebuild
```

---

## nixos-hardware Integration

### What nixos-hardware Provides

The `nixos-hardware` profiles provide hardware-specific optimizations:
- **Dell Latitude 7280:** Intel graphics, power management, thermal tuning
- **Dell XPS 13 9370:** HiDPI, Thunderbolt, WiFi, touchpad, graphics

**Profile Location in Flake:**
```nix
# In flake.nix
inputs.nixos-hardware.nixosModules.dell-latitude-7280
inputs.nixos-hardware.nixosModules.dell-xps-13-9370
```

### Viewing Applied Optimizations

```bash
# Check what the hardware profile configures
nix repl
:lf .
:p nixosConfigurations.transporter.config.hardware
```

---

## Troubleshooting Hardware Issues

### Graphics Issues

**Check Graphics Driver:**
```bash
# Current driver
glxinfo | grep "OpenGL renderer"

# Kernel modules
lsmod | grep -E 'i915|nvidia|amdgpu'
```

### Audio Issues

**Check Pipewire Status:**
```bash
# Pipewire services
systemctl --user status pipewire pipewire-pulse wireplumber

# List audio devices
pactl list sinks
pw-cli list-objects | grep node.name
```

### Network Issues

**Check WiFi:**
```bash
# NetworkManager status
nmcli device status
nmcli connection show

# WiFi signal
nmcli device wifi list
```

### Boot Issues

**Access Previous Generations:**
- At systemd-boot menu, select older generation
- Last 5 generations kept (configured in modules/common/boot.nix)

**Boot Logs:**
```bash
# View boot log
journalctl -b

# Previous boot
journalctl -b -1
```

---

## Future Hardware Additions

When adding new machines to ClaudeOS:

1. **Check nixos-hardware:** https://github.com/NixOS/nixos-hardware
2. **Create host config:** `hosts/<hostname>/default.nix`
3. **Generate hardware config:** `nixos-generate-config`
4. **Add to flake.nix:** New nixosConfiguration
5. **Document in this file:** Specs, issues, optimizations

---

*Last updated: 2026-02-02*
