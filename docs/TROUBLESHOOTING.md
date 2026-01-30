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

### Home Directory Ownership After Install

**Symptom:** Permission errors when trying to write to home directory after fresh installation

**Cause:** NixOS installer creates `/home/tom` with root ownership

**Solution:**
```bash
sudo chown -R tom:users /home/tom
```

**Prevention:** This is a one-time issue after installation, documented for all future deployments

**Status:** Resolved on transporter, documented for gti

---

## Desktop Issues

### Package Renamed: noto-fonts-emoji

**Symptom:** Build fails with error about unknown package `noto-fonts-emoji`

**Cause:** nixpkgs renamed package to `noto-fonts-color-emoji`

**Solution:** Update modules/desktop/fonts.nix:
```nix
# Old
noto-fonts-emoji

# New
noto-fonts-color-emoji
```

**Status:** Fixed in modules/desktop/fonts.nix

---

### Package Renamed: nerdfonts

**Symptom:** Build fails referencing `nerdfonts.override` or `nerdfonts` package

**Cause:** nixpkgs split nerdfonts into individual packages

**Solution:** Update to new package names:
```nix
# Old
(pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" "FiraCode" ]; })

# New
pkgs.nerd-fonts.jetbrains-mono
pkgs.nerd-fonts.fira-code
```

**Status:** Fixed in modules/desktop/fonts.nix

---

### GNOME Extensions Not Visible

**Symptom:** Installed extensions don't appear in GNOME

**Cause:** Extensions need to be manually enabled in GNOME Extension Manager or Settings

**Solution:**
1. Open GNOME Extension Manager (installed via modules/desktop/gnome.nix)
2. Enable desired extensions: Appindicator, Just Perfection, Caffeine
3. Alternatively, use `gnome-extensions list` and `gnome-extensions enable <uuid>`

**Note:** Extensions are installed system-wide but must be enabled per-user

---

###Wayland vs X11 Session

**Symptom:** Application behaves differently or doesn't work as expected

**Cause:** Some applications work better on X11 or Wayland

**Solution:**
```bash
# Check current session type
echo $XDG_SESSION_TYPE

# Switch at login (click gear icon in GDM)
# Options: "GNOME" (Wayland) or "GNOME on Xorg" (X11)
```

**Current Configuration:** Wayland by default with X11 fallback available

---

## Application Issues

### Unwanted Launcher Icons

**Symptom:** CLI tools (vim, htop, yazi, xterm) appear in application launcher

**Cause:** Some packages install desktop files even though they're CLI tools

**Solution 1 - System Packages (xterm):**
```nix
# In modules/desktop/gnome.nix
services.xserver.excludePackages = with pkgs; [
  xterm
];
```

**Solution 2 - Home Manager Packages:**
```nix
# In home/default.nix or relevant module
xdg.dataFile."applications/vim.desktop".text = ''
  [Desktop Entry]
  Hidden=true
'';
```

**Status:** Fixed for xterm, vim, htop, micro, yazi

---

### Fish Plugin Hash Mismatch

**Symptom:** Build fails with hash mismatch errors for Fish plugins

**Example Error:**
```
error: hash mismatch in fixed-output derivation '/nix/store/...-fishPlugins.z':
  specified: sha256-xyz...
  got:      sha256-abc...
```

**Cause:** Plugin source changed or incorrect hash in configuration

**Solution:**
1. Note the "got:" hash from error message
2. Update hash in home/shell/fish.nix:
```nix
plugins = [
  {
    name = "z";
    src = pkgs.fetchFromGitHub {
      owner = "jethrokuan";
      repo = "z";
      rev = "...";
      sha256 = "correct-hash-here";  # Use the "got:" hash
    };
  }
];
```

**Status:** Fixed for z and fzf.fish plugins

---

### Duplicate Chrome Launcher Icon

**Symptom:** Multiple Chrome icons in application launcher

**Cause:** Conflicting desktop files

**Solution:** Proper desktop file management in modules/apps/browsers.nix (no custom desktop files needed)

**Status:** Resolved

---

### Terminal Doesn't Have Native GNOME Decorations

**Symptom:** Terminal window decorations don't match GNOME theme (WezTerm issue)

**Cause:** WezTerm doesn't use GTK/libadwaita for window decorations

**Solution:** Switched to Ghostty terminal emulator
- Ghostty uses GTK/libadwaita for native GNOME integration
- Configured in modules/apps/terminals.nix and home/ghostty.nix

**Status:** Resolved by migrating to Ghostty in Phase 3

---

### Claude Code CLI Not in PATH

**Symptom:** `claude` command not found after installation

**Cause 1:** ~/.local/bin not in PATH
**Solution:** Added to PATH in home/shell/fish.nix via `fish_add_path`

**Cause 2:** Wrong installation directory
**Note:** Installer changed from `~/.claude/bin` to `~/.local/bin`

**Solution:**
```bash
# Verify installation location
which claude

# Should return: /home/tom/.local/bin/claude

# If not found, check if installer ran successfully
ls -la ~/.local/bin/claude

# Re-run installer if needed
curl -fsSL https://claude.ai/install.sh | bash

# Reload Fish config
source ~/.config/fish/config.fish
```

**Status:** Fixed in Phase 4 deployment

---

### VSCode Extensions Can't Be Managed Declaratively

**Symptom:** VSCode extensions in home/vscode.nix don't install

**Cause:** home-manager only supports declarative extensions for VSCodium, not VSCode

**Solution:** Manual installation required
1. Open VSCode
2. Go to Extensions (Ctrl+Shift+X)
3. Search and install Claude extension
4. Other Nix-related extensions (nix-ide, direnv) ARE managed declaratively

**Note:** This is a limitation of VSCode (unfree) vs VSCodium (free)

**Status:** Documented as manual step in modules/apps/claude.nix

---

## Known Issues

### Current Limitations

1. **sops-nix not configured:** No declarative secrets management (intentional - see SECRETS.md)
2. **Atuin sync disabled:** Shell history not synchronized across machines (can enable with sops-nix)
3. **Git identity not configured:** Must set user.name and user.email manually
4. **VSCode Claude extension:** Must be installed manually (VSCode limitation)
5. **Chrome extensions:** Must be installed manually (browser limitation)

### Expected Future Issues

**Phase 5 (gti deployment):**
- Dell XPS-specific hardware issues may arise
- Display scaling configuration might be needed (HiDPI)
- Touchpad sensitivity tuning may be required

---

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
