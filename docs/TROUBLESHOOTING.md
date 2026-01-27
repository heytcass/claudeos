# Troubleshooting Guide

**This file will be updated as issues are encountered.**

Common issues, solutions, and debugging procedures.

## Build Issues

### Flake Check Fails

**Symptom:** `nix flake check` reports errors

**Solutions:**
1. Check syntax: `nixpkgs-fmt --check .`
2. Check for common issues: `statix check`
3. Look for undefined variables: `deadnix -e`
4. Read error message carefully - includes file and line number
5. Verify all imports exist
6. Check module options are defined before use

### Can't Enter Dev Shell

**Symptom:** `nix develop` fails

**Solutions:**
1. Verify Nix is installed: `nix --version`
2. Ensure flakes are enabled in nix.conf
3. Try: `nix develop --refresh`
4. Update flake: `nix flake update`
5. Check flake.lock exists

### Build Fails with "attribute missing"

**Symptom:** Error about missing package or option

**Solutions:**
1. Check package name is correct in nixpkgs
2. Search packages: `nix search nixpkgs <package>`
3. Verify unfree packages enabled if needed
4. Check option exists: `nixos-option <option.path>`

## Deployment Issues

### SSH Connection Fails

**Symptom:** Can't SSH to target machine

**Solutions:**
1. Check network: `ping <hostname>`
2. Verify SSH service running
3. Check firewall rules
4. Try IP address instead of hostname
5. Verify SSH keys if using key auth

### Deployment Fails on Target

**Symptom:** `nixos-rebuild switch` fails

**Solutions:**
1. Check error message carefully
2. Verify git repo is up to date: `git status`, `git pull`
3. Check disk space: `df -h`
4. Try rollback: `sudo nixos-rebuild switch --rollback`
5. Check logs: `journalctl -xe`

### Changes Don't Apply

**Symptom:** Configuration changes not visible after rebuild

**Solutions:**
1. Verify changes were committed and pushed
2. Verify target pulled latest: `git log`
3. Check you rebuilt with correct flake: `--flake .#<hostname>`
4. Verify generation changed: `nixos-rebuild list-generations`
5. May need reboot for some changes (kernel, boot, etc.)

## Runtime Issues

### Module Not Found

**Symptom:** Error about missing module during evaluation

**Solutions:**
1. Check module file exists
2. Verify import path is correct
3. Check `default.nix` imports the module
4. Verify no typos in module name

### Service Won't Start

**Symptom:** Service fails to start after rebuild

**Solutions:**
1. Check service status: `systemctl status <service>`
2. Check logs: `journalctl -u <service>`
3. Verify service is enabled
4. Check configuration options are correct
5. Try starting manually: `systemctl start <service>`

## Hardware Issues

_To be populated as issues are encountered_

## Desktop Issues

_To be populated in Phase 2_

## Application Issues

_To be populated in Phase 3-4_

## Known Issues

_None yet - will be documented as discovered_

## Getting Help

If you can't resolve an issue:
1. Check this file for similar issues
2. Review module documentation: [MODULES.md](./MODULES.md)
3. Check NixOS wiki: https://wiki.nixos.org
4. Search NixOS discourse: https://discourse.nixos.org
5. Use AskUserQuestion tool to ask the user

## Rollback Procedure

If something breaks badly:

```bash
# On target machine

# See available generations
sudo nixos-rebuild list-generations

# Rollback to previous generation
sudo nixos-rebuild switch --rollback

# Or switch to specific generation
sudo nixos-rebuild switch --switch-generation <number>

# Reboot if needed
sudo reboot
```

Generations are also available in boot menu (systemd-boot) - select older generation to boot.

---

_This file will be updated throughout implementation as issues are discovered._
