# ClaudeOS Status

**Last Updated:** 2026-06-12

## Current State

ClaudeOS is a fully operational NixOS configuration for personal machines.

### Hosts: gti (primary) + transporter (testbed)

gti (Dell XPS 13 9370) is the primary machine — currently running Ubuntu pending the ClaudeOS reinstall. transporter (Dell Latitude 7280) is the testbed host proving the integration story before the reinstall.

**What works:**
- GNOME on Wayland (GDM, trimmed default app set) with Claude keybindings (Super+C / Super+A / Super+Shift+A / Super+Ctrl+A)
- Pipewire audio with Bluetooth
- Ghostty terminal with Fish shell and Starship prompt
- Modern CLI tools (eza, bat, zoxide, atuin, yazi, fzf, ripgrep, fd) + uutils coreutils at hiPrio on the user PATH
- Chrome, Slack, Discord, Teams, Obsidian, VSCode (extensions Marketplace-managed)
- Claude Code CLI (via nix-ld) with seed-once settings/MCP config and repo-tracked hooks
- Claude Desktop (via claude-desktop-linux)
- Stylix theming with Claude brand colors
- btrfs with zstd compression and subvolumes (snapper timeline + number cleanup)
- `rebuild` flow: haiku-named generation labels (system.nixos.tags), named snapper pre/post snapshots, `nh os switch`, auto-commit
- nh declarative GC + nvd/nom; comma + nix-index-database (`, foo`; command-not-found disabled)
- Oxidized ring: sudo-rs, envfs, dbus-broker, scx_lavd (--autopower)
- Self-maintaining layer: self-heal fix PRs on unit failure, nightly journal diary against docs/known-issues.md, morning desk dashboard, 15-min health monitor, 9 AM daily brief
- Weekly auto-update service (git pull --rebase, flake update, test build, Claude changelog + generation slug, verified push)
- systemd-boot with 5 generations retained and the boot-entry editor disabled

## Module Summary

| Category | Modules | Purpose |
|----------|---------|---------|
| common/ | boot, disko, nix, users, networking, locale, system, secrets, snapshots, auto-update, generation-label, self-heal | Foundation |
| desktop/ | gnome, audio, fonts, theme | GNOME desktop |
| apps/ | terminals, claude, jasper, mcp-system-health, claude-monitor, morning-desk | Applications + AI |
| home/ | shell (fish, cli-tools, starship), ghostty, git, vscode, gnome, macchina, claude-code, claudeos-help, zathura, imv | User config |

## Future Enhancements

- [x] Deploy to gti (production machine)
- [x] sops-nix for declarative secrets management
- [x] Automated btrfs snapshots before rebuilds (snapper with pre/post rebuild pairs)
- [x] Declarative Claude Code configuration (settings.json + .mcp.json from Nix)
- [x] System health MCP server for Claude Code diagnostics
- [x] Desktop keybindings for Claude Code (Super+C) and the ask/screenshot scripts (Super+A / Super+Shift+A / Super+Ctrl+A)
- [x] Laptop power management (power-profiles-daemon + scx_lavd --autopower)
- [ ] NixOS impermanence for stateless system
- [ ] Binary cache for faster builds
- [ ] Atuin sync (currently disabled; the `atuin_key` sops declaration was removed — re-declare in `modules/common/secrets.nix` when enabling)
- [ ] Declare `unifi_api_key` secret for the UniFi MCP server (`.mcp.json` reads it from the environment)
- [ ] Compositor experiments (Hyprland, etc.) as specialisations
- [ ] Point archive mimeApps at File Roller (still reference xarchiver.desktop)

## Maintenance Log

### 2026-06-12
- Desktop pivot: Niri + Noctalia retired in favor of GNOME on Wayland
  - `modules/desktop/gnome.nix` (GDM, services.desktopManager.gnome, trimmed default apps); `home/gnome.nix` dconf (Colemak input, idle/lock policy, four Claude keybindings on Super)
  - `mcp-niri` MCP server removed; Thunar/xarchiver replaced by Nautilus/File Roller from GNOME's default set (note: archive mimeApps in `home/default.nix` still name xarchiver.desktop — leftover); zenity + gnome-screenshot back the desktop Claude scripts
  - Compositor experiments (Hyprland) may return later as specialisations
- Oxidized ring: sudo-rs replaces sudo; services.envfs (the /bin/bash activation hack is gone); dbus-broker; scx_lavd BPF scheduler with --autopower; uutils-coreutils at hiPrio on the user PATH; programs.nh + nvd + nix-output-monitor (declarative GC replaces nix.gc.automatic); nix-index-database + comma (command-not-found disabled). New flake input: nix-index-database
- Time-machine chain: repo-root `generation-label` → system.nixos.tags (`modules/common/generation-label.nix`); fish `rebuild` writes a haiku slug per rebuild and names snapper pre/post snapshots with it; auto-update writes slugs for weekly updates; system.configurationRevision from self.shortRev
- Self-maintaining layer:
  - `modules/common/self-heal.nix`: claude-heal@.service OnFailure template — watched units get an agent that opens fix PRs on heal/* branches (option claude-os.selfHeal)
  - claude-monitor Tier 4 journal diary: nightly 4 AM haiku triage against the docs/known-issues.md ledger; actionable items feed the morning brief
  - Repo-tracked Claude Code hooks (.claude/settings.json + .claude/hooks/): SessionStart OS-awareness, PostToolUse nixfmt + parse-check on .nix edits, PreToolUse denies `git commit` of staged .nix unless `nix flake check --no-build` passes
  - Fish functions `approve` (resume last agent session) and `today`
- Morning desk (`modules/apps/morning-desk.nix`): 05:30 agent builds ~/Desk/today/index.html (self-contained Stylix-themed dashboard, attention-first hierarchy), auto-opened in Chrome --app mode at first login; calendar via gcalcli (one-time `gcalcli init` with the Google OAuth client in sops); archives to ~/Desk/archive/
- Claude Code config is now seed-once (two-ring): ~/.claude/settings.json and .mcp.json seeded on first activation then mutable; VSCode extensions Marketplace-managed; statusline is a `claude-statusline` command
- Flake inputs now: nixpkgs, home-manager, nixos-hardware, sops-nix, disko, claude-desktop-linux (follows main nixpkgs again), stylix, jasper, treefmt-nix, nix-index-database

### 2026-06-11
- Security/quality audit cleanup
  - Briefly removed transporter from the flake, then re-added it as a testbed host with a pinned disk device
  - Disko: ESP grown to 1G; no default disk device (each host pins its own)
  - Boot: configurationLimit 5, systemd-boot editor disabled
  - Snapper: NUMBER_CLEANUP/NUMBER_LIMIT/EMPTY_PRE_POST_CLEANUP on root + home
  - Auto-update: git pull --rebase before update, verified push with rebase retry
  - Polkit: removed manage-unit-files from passwordless wheel rule
  - Removed undeclared atuin_key sops declaration; .mcp.json UniFi key now read from environment
  - Thunar via programs.thunar (+xfconf) with plugins; dropped services.xserver.xkb; LLMNR off; fstrim on
  - EDITOR/VISUAL = code --wait; programs.gh consolidated into home/shell/cli-tools.nix
  - imv colors from Stylix palette; swayidle explicit PATH + attrset events
  - Documentation synchronized with the above

### 2026-02-15
- Phase 4: Deep Claude Integration
  - Declarative Claude Code config (settings.json + .mcp.json from Nix)
  - Snapper btrfs snapshots with pre/post rebuild safety
  - System health MCP server (8 diagnostic tools)
  - COSMIC keybindings: Super+C (Claude Code), Ctrl+Alt+Space (Claude Desktop)
  - Desktop notifications via notify-send hooks

### 2026-02-14
- Hardened CLAUDE.md with theming conventions, workflow guardrails, and config location rules
- Centralised hardcoded destructive red into lib/theme.nix extended palette
- Updated documentation to reflect current state

### 2026-02-12
- Added SOPS/age runtime secret decryption for Jasper daemon
- Deployed gti (Dell XPS 13 9370) to production

### 2026-02-10
- Added macchina system fetch with custom ASCII art and Stylix-themed colors
- Redesigned Starship prompt to match Claude Code aesthetic
- Flake updates and breaking change fixes (stale patches)
- Config cleanup, Claude automation improvements

### 2026-02-02
- Major cleanup: removed dead code, consolidated documentation, updated for direct NixOS workflow

### 2026-01-30
- Migrated from GNOME to COSMIC desktop
- Replaced WezTerm with Ghostty
- Added Stylix theming with Claude brand colors
- Added Claude Desktop via claude-for-linux flake
- Post-migration cleanup and hardening

### 2026-01-27
- Initial deployment to transporter (Phases 1-4)
- Core system, desktop, applications, Claude Code CLI
- btrfs filesystem with subvolumes
