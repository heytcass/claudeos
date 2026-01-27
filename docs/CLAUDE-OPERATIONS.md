# ClaudeOS Operations Guide

**Context:** You are helping administer a live NixOS system running ClaudeOS configuration.

## Critical Operations Rules

1. **Configuration changes happen on dev machine** - Don't edit `/etc/nixos` directly on target
2. **Use rollbacks liberally** - NixOS makes it safe to experiment
3. **Check journal first** - Most issues show up in systemd logs
4. **Verify before rebooting** - Use `nixos-rebuild test` when possible

## Quick Commands

### System Status
```bash
# Overall system health
systemctl status

# Failed services
systemctl --failed

# Recent boot logs
journalctl -b

# Disk usage
df -h
```

### Service Management
```bash
# Check service status
systemctl status <service>

# View service logs
journalctl -u <service> -f

# Restart service
sudo systemctl restart <service>

# Enable/disable service
sudo systemctl enable/disable <service>
```

### Configuration Management
```bash
# See current generation
nixos-rebuild list-generations

# Rollback to previous generation
sudo nixos-rebuild switch --rollback

# Test new config without switching
sudo nixos-rebuild test --flake .#<hostname>

# Switch to new config
sudo nixos-rebuild switch --flake .#<hostname>

# Pull latest config from git
cd ~/.config/claudeos && git pull
```

### Troubleshooting
```bash
# Hardware info
lspci
lsusb
dmesg | tail -50

# Network status
ip addr
nmcli device status
nmcli connection show

# GNOME/Wayland issues
journalctl -u display-manager
echo $XDG_SESSION_TYPE  # Should be 'wayland'
loginctl show-session $(loginctl | grep tom | awk '{print $1}') -p Type

# Audio issues (Pipewire)
systemctl --user status pipewire pipewire-pulse wireplumber
pw-cli info all
```

### Log Locations
```bash
# Systemd journal (most services)
journalctl -u <service>

# Boot messages
journalctl -b

# Kernel messages
dmesg

# X11/Wayland session
~/.local/share/xorg/
journalctl --user

# GNOME logs
journalctl -u gdm
```

## Common Scenarios

### "Service won't start"
1. Check status: `systemctl status <service>`
2. View logs: `journalctl -u <service> -n 50`
3. Check config: `systemctl cat <service>`
4. Try restart: `sudo systemctl restart <service>`

### "System is slow/unresponsive"
1. Check CPU/memory: `htop` or `top`
2. Check disk: `df -h` and `iotop`
3. Recent journal: `journalctl -n 100`
4. Failed services: `systemctl --failed`

### "Network not working"
1. Check interfaces: `ip addr`
2. Check NetworkManager: `nmcli device status`
3. Check DNS: `resolvectl status`
4. Check logs: `journalctl -u NetworkManager`

### "GNOME issues"
1. Check session type: `echo $XDG_SESSION_TYPE`
2. Restart display manager: `sudo systemctl restart gdm`
3. Check GDM logs: `journalctl -u gdm`
4. Check Wayland compositor: `journalctl --user -u gnome-shell`

### "Audio not working"
1. Check Pipewire: `systemctl --user status pipewire pipewire-pulse wireplumber`
2. List devices: `pw-cli info all | grep -A 5 "node.name"`
3. Restart Pipewire: `systemctl --user restart pipewire pipewire-pulse wireplumber`
4. Check logs: `journalctl --user -u pipewire`

## System Information

### Current Configuration
```bash
# View current NixOS configuration
cat /etc/nixos/configuration.nix  # (should be minimal/redirect to flake)

# View current generation
ls -l /nix/var/nix/profiles/system

# See what's in current generation
nix-store -q --tree /run/current-system
```

### Hardware Details
```bash
# CPU info
lscpu

# Memory info
free -h

# Disk info
lsblk
fdisk -l

# PCI devices
lspci -v

# USB devices
lsusb -v
```

## Emergency Recovery

### System Won't Boot
1. Select previous generation in GRUB
2. Boot into working system
3. Investigate: `journalctl -b -1` (previous boot)
4. Rollback if needed: `sudo nixos-rebuild switch --rollback`

### Can't Login (GDM)
1. Switch to TTY: Ctrl+Alt+F2
2. Login as user
3. Check GDM: `sudo systemctl status gdm`
4. Logs: `journalctl -u gdm`
5. Test restart: `sudo systemctl restart gdm`

### Out of Disk Space
1. Check usage: `df -h`
2. Clean old generations: `sudo nix-collect-garbage --delete-older-than 7d`
3. Optimize store: `sudo nix-store --optimise`

## Machines

### transporter (Dell Latitude 7280)
- **IP:** 10.0.10.205
- **User:** tom
- **SSH:** `ssh tom@10.0.10.205`
- **Status:** Phase 2 complete (GNOME 49.2, Wayland, Pipewire)
- **Config location:** `~/.config/claudeos`

### gti (Dell XPS 13 9370)
- **Status:** Not yet deployed
- **Hardware:** i7-8550U, 16GB RAM, 512GB NVMe

## Quick Fixes

### Rebuild from Latest Git
```bash
cd ~/.config/claudeos
git pull
sudo nixos-rebuild switch --flake .#$(hostname)
```

### Force Garbage Collection
```bash
sudo nix-collect-garbage --delete-older-than 3d
sudo nixos-rebuild boot  # Keep current generation bootable
```

### Reset User Session (GNOME)
```bash
# Backup first
cp -r ~/.config/gnome-shell ~/.config/gnome-shell.backup

# Reset
dconf reset -f /org/gnome/

# Re-login (logout/login or restart GDM)
```

## Monitoring

### System Resources
```bash
# Real-time monitoring
htop

# Disk I/O
iotop

# Network
iftop

# Process tree
pstree -p
```

### Service Health
```bash
# All services
systemctl list-units --type=service

# Failed services
systemctl --failed

# Enabled services
systemctl list-unit-files --state=enabled
```

## Notes

- Configuration source is Git (Ubuntu dev machine)
- Target machines pull from Git, never edit locally
- Always use `--flake .#<hostname>` for rebuilds
- Rollbacks are safe and instant
- Generation cleanup happens automatically after 7 days
