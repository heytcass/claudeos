# Hardware Documentation

**Complete hardware documentation will be added in Phase 6.**

This file will document:
- Hardware-specific configurations
- Known hardware issues
- Workarounds and fixes
- Performance tuning
- Power management

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

**Status:** ✅ Phase 1 complete and tested

**Installation Date:** 2026-01-27

**Known Issues:**
- Home directory ownership needs fixing after initial install: `sudo chown -R tom:users /home/tom`

**Working Features:**
- systemd-boot bootloader
- Fish shell
- US Colemak keyboard layout
- NetworkManager
- SSH access
- Git, vim, htop
- Nix flakes

### gti - Dell XPS 13 9370

**Hardware Profile:** `nixos-hardware.nixosModules.dell-xps-13-9370`

**Specs:** (To be documented)
- CPU: Intel
- RAM: TBD
- Storage: TBD
- Display: TBD
- Network: TBD

**Status:** Production (Phase 5)

**Known Issues:** TBD

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

**Recommended Tweaks for Phase 2+:**
- Consider btrfs snapshots before/after system rebuilds
- May want to adjust swappiness for SSD longevity

### Dell XPS 13 9370

_To be documented after deployment_

---

_This file will be completed in Phase 6 with actual hardware details._
