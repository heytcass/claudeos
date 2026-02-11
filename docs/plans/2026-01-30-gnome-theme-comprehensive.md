# GNOME Theme Comprehensive Design

**Date:** 2026-01-30
**Status:** Approved for implementation
**Branch:** `feature/gnome-theme-comprehensive`

## Overview

Comprehensive GNOME visual theme with Papirus icons, custom accent colors, and Shell customization. Builds on existing Stylix base16 implementation to create a cohesive Claude-branded desktop environment.

## Goals

- Custom icon theme (Papirus) with terracotta folder colors
- GNOME accent color integration (hybrid approach)
- Minimal Shell customization (stability over bling)
- No cursor theme (fragile with Electron apps)
- Feature branch for easy rollback

## Research Findings

### Stylix Capabilities

**What Stylix handles:**
- GTK3/GTK4 application theming via CSS generation
- GNOME Shell theming (replaces theme at package level)
- 100+ applications (terminals, editors, browsers, dev tools)
- System fonts, wallpapers

**What requires manual configuration:**
- Icon themes (Stylix can set package but doesn't generate/recolor)
- GNOME accent colors (Stylix overrides via CSS, not native API)
- Papirus folder colorization (requires `papirus-folders` script)
- GNOME-specific dconf settings

### GNOME Accent Color Limitations

**Key finding:** GNOME 47+ accent colors are locked to 9 enum presets:
- `blue`, `teal`, `green`, `yellow`, `orange`, `red`, `pink`, `purple`, `slate`
- Cannot accept custom hex colors via dconf
- Schema type is `enum`, not color value

**Closest match:** "orange" (`#ed5b00`) is closest to terracotta (`#c6613f`)

**Hybrid solution:**
- Set GNOME accent to "orange" for Shell UI
- Stylix CSS overrides provide exact terracotta in GTK apps
- 15% color difference barely noticeable in practice

### Community Patterns

**NixOS best practices** (from dbeley, Nissi-Jacobson, fufexan configs):
1. Split Stylix between NixOS system-level and Home Manager user-level
2. Keep GNOME configuration separate from Stylix
3. Home Manager owns: dconf, gtk, icon themes, user preferences
4. NixOS owns: Stylix base config, system services, GDM theming
5. Use `dconf watch /` to discover settings, convert with `dconf2nix`

## Architecture

### Module Organization

```
modules/desktop/
├── theme.nix           # NixOS: Stylix base16Scheme, system config
├── theme-home.nix      # Home Manager: Stylix targets, Papirus activation
└── gnome.nix          # Home Manager: dconf settings, GTK config
```

### Configuration Layers

**Layer 1 - Stylix Foundation:**
- Base16 color scheme (existing)
- GTK/Shell CSS generation
- System-wide app theming

**Layer 2 - Icon Theme:**
- Papirus-Dark icon package
- Folder colorization via `papirus-folders` script
- Home Manager activation script

**Layer 3 - GNOME Integration:**
- Accent color set to "orange" via dconf
- GTK theme preferences (dark mode)
- Built-in rounded corners (GNOME 47+ feature)

**Layer 4 - Skip:**
- Cursor theme (fragile, breaks with Electron)
- Heavy extensions (stability over bling)
- User Themes extension (package conflicts in GNOME 49)

## Implementation Details

### `modules/desktop/theme.nix` (NixOS)

```nix
{ pkgs, ... }: {
  stylix = {
    enable = true;

    # Existing base16 scheme
    base16Scheme = {
      base00 = "262624";  # Default background
      base01 = "30302e";  # Elevated surface
      base02 = "3a3a38";  # Selection
      base03 = "9c9a92";  # Comments
      base04 = "c2c0b6";  # Secondary foreground
      base05 = "faf9f5";  # Primary foreground
      base06 = "faf9f5";  # Light foreground
      base07 = "ffffff";  # Brightest white

      base08 = "c6613f";  # Red - terracotta accent
      base09 = "d97757";  # Orange
      base0A = "c9b87c";  # Yellow - warm sand
      base0B = "8a9a6b";  # Green - muted olive
      base0C = "6b9e8a";  # Cyan - warm sage
      base0D = "2c84db";  # Blue - link/info
      base0E = "a67a5b";  # Magenta - warm brown
      base0F = "d97757";  # Brown - lighter terracotta
    };

    polarity = "dark";
    image = null;  # No wallpaper

    # Icon theme via Stylix
    icons = {
      enable = true;
      package = pkgs.papirus-icon-theme;
    };
  };
}
```

### `modules/desktop/theme-home.nix` (Home Manager)

```nix
{ pkgs, lib, ... }: {
  stylix = {
    # Enable Stylix targets for apps
    targets = {
      gnome.enable = true;
      gtk.enable = true;
      ghostty.enable = true;
      vscode.enable = true;
      firefox.enable = true;
      # Add other apps as needed
    };

    # Optional: Custom GTK CSS overrides
    targets.gtk.extraCss = ''
      /* Manual CSS fixes if Stylix falls short */
    '';
  };

  # Papirus folder colorization
  home.activation.papirus-folders = lib.hm.dag.entryAfter ["writeBoundary"] ''
    ${pkgs.papirus-folders}/bin/papirus-folders -C brown --theme Papirus-Dark
  '';
}
```

### `modules/desktop/gnome.nix` (Home Manager)

```nix
{ lib, pkgs, ... }:
with lib.hm.gvariant;
{
  # GTK theme preferences
  gtk = {
    enable = true;

    # Icon theme (matches Stylix choice)
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };

    # Force dark mode preference
    gtk3.extraConfig.Settings = ''
      gtk-application-prefer-dark-theme=1
    '';
    gtk4.extraConfig.Settings = ''
      gtk-application-prefer-dark-theme=1
    '';
  };

  # GNOME desktop settings via dconf
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      accent-color = "orange";  # Closest to terracotta
    };

    "org/gnome/mutter" = {
      experimental-features = ["scale-monitor-framebuffer"];
    };
  };
}
```

## Import Structure

**NixOS configuration:**
```nix
imports = [
  ./modules/desktop/theme.nix
  # other system modules
];
```

**Home Manager configuration:**
```nix
imports = [
  ./modules/desktop/theme-home.nix
  ./modules/desktop/gnome.nix
  # other home modules
];
```

## Testing & Validation

### Post-Implementation Checklist

**Stylix theming:**
- [ ] GTK apps show terracotta accents
- [ ] Ghostty terminal uses theme colors
- [ ] VS Code uses base16 scheme
- [ ] Firefox themed appropriately

**GNOME Settings:**
- [ ] Settings → Appearance shows "orange" accent selected
- [ ] Dark mode active system-wide
- [ ] Rounded corners visible (GNOME 47+ built-in)

**Papirus icons:**
- [ ] Folder icons are brown/terracotta-toned
- [ ] App icons use Papirus-Dark variant
- [ ] Icon theme consistent across apps

**Discovery workflow:**
- [ ] Run `dconf watch /` to capture additional settings
- [ ] Change GNOME preferences as desired
- [ ] Add discovered dconf paths to `gnome.nix`

### Rollback Plan

If issues occur:
1. Switch back to `main` branch
2. Rebuild NixOS configuration
3. Feature branch preserved for debugging

## Dependencies

**System packages:**
- `pkgs.papirus-icon-theme`
- `pkgs.papirus-folders`

**NixOS modules:**
- Stylix (already configured)
- Home Manager (already configured)

**No new extensions required** - uses GNOME 47+ built-in features

## References

- [Stylix Documentation](https://nix-community.github.io/stylix/)
- [Papirus Icon Theme](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme)
- [GNOME 47 Accent Colors](https://release.gnome.org/47/)
- [libadwaita CSS Variables](https://gnome.pages.gitlab.gnome.org/libadwaita/doc/1.2/css-variables.html)
- Research: Stylix GNOME capabilities (agentId: a77caf8)
- Research: NixOS theme organization patterns (agentId: a3f6716)
- Research: GNOME custom accent colors (agentId: a032f3b)

## Next Steps

1. Create feature branch `feature/gnome-theme-comprehensive`
2. Implement modules in isolated worktree
3. Build and deploy to test machine (transporter)
4. Validate against checklist
5. Merge to main if successful
