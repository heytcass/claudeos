# Theme System

Comprehensive visual theme system built on Stylix base16 implementation. Creates a cohesive Claude-branded desktop environment with warm terracotta accent colors across applications.

## Overview

The ClaudeOS theme system uses Stylix's powerful base16 theming to create a consistent visual experience across the desktop environment. The theme features:

- **Custom color scheme** based on Claude's brand colors (warm terracotta accent)
- **Adwaita icon theme** for GTK/libadwaita applications
- **Dark mode by default** with system-wide consistency
- **100+ applications themed** via Stylix targets

## Architecture

The theme system is split across three modules following NixOS best practices:

### 1. `modules/desktop/theme.nix` (NixOS System-Level)

**Purpose:** System-wide Stylix configuration and base16 color scheme

**Responsibilities:**
- Defines the base16 color palette
- Enables Stylix for system-level theming
- Configures icon theme package
- Sets polarity (dark mode)

**Why system-level:** Color schemes and Stylix foundation need to be available at boot and for system services.

### 2. `home/theme.nix` (Home Manager)

**Purpose:** User-level Stylix targets and application theming

**Responsibilities:**
- Enables Stylix for specific applications (Ghostty, VS Code, Firefox, etc.)
- Configures per-user theme preferences
- Provides GTK CSS override hooks if needed

**Why Home Manager:** Application-specific theming belongs in the user session, not system-wide.

### 3. `home/cosmic.nix` (Home Manager)

**Purpose:** COSMIC-specific settings via dconf and GTK configuration

**Responsibilities:**
- Sets GTK icon theme (Adwaita) for GTK app compatibility
- Configures GTK dark mode preferences
- Manages dconf settings for GTK applications running under COSMIC

**Why separate:** COSMIC uses its own configuration system (`~/.config/cosmic/`) independent of Stylix. This module ensures GTK applications have proper theming when running under COSMIC.

## Color Scheme

The ClaudeOS base16 scheme uses warm, earthy tones inspired by Claude's brand identity:

```nix
base16Scheme = {
  base00 = "262624";  # Default background - deep charcoal
  base01 = "30302e";  # Elevated surface - slightly lighter
  base02 = "3a3a38";  # Selection background
  base03 = "9c9a92";  # Comments, disabled text
  base04 = "c2c0b6";  # Secondary foreground
  base05 = "faf9f5";  # Primary foreground - warm white
  base06 = "faf9f5";  # Light foreground
  base07 = "ffffff";  # Brightest white

  base08 = "c6613f";  # Red - terracotta accent (primary brand color)
  base09 = "d97757";  # Orange - lighter terracotta
  base0A = "c9b87c";  # Yellow - warm sand
  base0B = "8a9a6b";  # Green - muted olive
  base0C = "6b9e8a";  # Cyan - warm sage
  base0D = "2c84db";  # Blue - links and info states
  base0E = "a67a5b";  # Magenta - warm brown
  base0F = "d97757";  # Brown - lighter terracotta
};
```

**Design philosophy:**
- Warm neutrals (browns, grays) for backgrounds
- Terracotta (`#c6613f`) as the primary accent color
- Muted earth tones for semantic colors (green, yellow, cyan)
- Bright blue (`#2c84db`) preserved for links and information states

## Icon Theme

**Package:** `pkgs.adwaita-icon-theme`

**Variant:** Adwaita (standard icon theme for GTK/libadwaita)

Adwaita provides symbolic icons that integrate well with GTK applications and the modern libadwaita design language. COSMIC uses its own icon system, but GTK applications running under COSMIC respect this theme setting.

### Implementation Details

**System level (theme.nix):**
```nix
stylix.icons = {
  enable = true;
  package = pkgs.adwaita-icon-theme;
};
```

**Home Manager (cosmic.nix):**
```nix
gtk.iconTheme = {
  name = "Adwaita";
  package = pkgs.adwaita-icon-theme;
};
```

## Configuration Layers

The theme system builds up in three distinct layers:

### Layer 1: Stylix Foundation
- Base16 color scheme definition
- Automatic CSS generation for GTK3/GTK4
- System-wide application theming (100+ apps)
- Terminal color schemes

### Layer 2: Icon Theme
- Adwaita package installation
- GTK icon theme configuration
- Symbolic icon support for modern applications

### Layer 3: Desktop Integration
- COSMIC desktop environment
- GTK dark mode preference enforcement
- dconf settings for GTK application compatibility

## Testing

### Visual Validation Checklist

**Stylix theming:**
- [ ] GTK apps display terracotta accent colors
- [ ] Ghostty terminal uses base16 color scheme
- [ ] VS Code shows themed interface
- [ ] Firefox themed (toolbars, menus)
- [ ] Check syntax highlighting in terminal and editors

**Desktop settings:**
- [ ] Dark mode active system-wide
- [ ] GTK applications integrate well with COSMIC
- [ ] Icon consistency across applications

**Integration:**
- [ ] Smooth color transitions in applications
- [ ] Terminal and GUI apps feel cohesive
- [ ] No visual conflicts between Stylix CSS and desktop theme

## Customization

### Changing the Color Scheme

Edit `modules/desktop/theme.nix`:

```nix
stylix.base16Scheme = {
  # Modify any base00-base0F values
  base08 = "your-accent-hex";  # Change primary accent
  # ...
};
```

Rebuild and log out/in to apply changes.

### Changing Icon Theme

Edit `modules/desktop/theme.nix` and `home/cosmic.nix`:

```nix
# In theme.nix
stylix.icons.package = pkgs.your-icon-theme;

# In cosmic.nix
gtk.iconTheme = {
  name = "Your-Theme-Name";
  package = pkgs.your-icon-theme;
};
```

### Adding Stylix Targets

Edit `home/theme.nix`:

```nix
stylix.targets = {
  # Enable theming for additional applications
  alacritty.enable = true;
  kitty.enable = true;
  # See Stylix documentation for full list
};
```

Available targets: `bat`, `firefox`, `fish`, `fzf`, `gnome-terminal`, `gtk`, `helix`, `hyprland`, `kitty`, `tmux`, `vim`, `vscode`, `waybar`, `zsh`, and many more.

## Troubleshooting

### GTK Apps Not Themed

**Symptom:** Some GTK applications ignore Stylix theming

**Solution:**
1. Verify Stylix targets are enabled in `home/theme.nix`
2. Check that the app is supported by Stylix
3. Force GTK4 apps to prefer dark theme:
```bash
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
```

### Icons Not Appearing Correctly

**Symptom:** Missing or incorrect icons in applications

**Solution:**
```bash
# Rebuild icon cache
gtk-update-icon-cache ~/.icons/Adwaita

# Verify icon theme package is installed
nix-store -q --references ~/.nix-profile | grep adwaita-icon-theme
```

### Cursor Theme Issues with Electron

**Symptom:** Cursor looks different in VS Code or Claude Desktop

**Expected behavior:** Electron apps often override cursor themes. This is why we don't configure a custom cursor theme - it would be inconsistent anyway.

**Workaround:** Accept default cursor in Electron apps, or configure per-app if really needed.

## Rollback

If theme issues occur:

### Quick Rollback
```bash
# Switch to previous generation
sudo nixos-rebuild switch --rollback

# Or switch to specific generation
sudo nixos-rebuild switch --switch-generation 123
```

### Branch Rollback
```bash
# Return to main branch
git checkout main

# Rebuild from main
sudo nixos-rebuild switch --flake ~/.config/claudeos#$(hostname)
```

## Import Structure

### NixOS Configuration

In your main configuration (e.g., `hosts/transporter/configuration.nix`):

```nix
imports = [
  ../../modules/desktop/theme.nix
  # other modules
];
```

### Home Manager Configuration

In your Home Manager config (e.g., `home/default.nix`):

```nix
imports = [
  ./theme.nix
  ./cosmic.nix
  # other modules
];
```

## Dependencies

**System packages required:**
- `pkgs.adwaita-icon-theme` - Icon theme package

**NixOS modules:**
- Stylix (configured at system level)
- Home Manager (for user-level theming)

## References

- [Stylix Documentation](https://nix-community.github.io/stylix/) - Official Stylix theming engine docs
- [Adwaita Icon Theme](https://gitlab.gnome.org/GNOME/adwaita-icon-theme) - Icon theme repository
- [libadwaita CSS Variables](https://gnome.pages.gitlab.gnome.org/libadwaita/doc/1.2/css-variables.html) - CSS customization reference
- [Base16 Styling Guidelines](https://github.com/chriskempson/base16/blob/main/styling.md) - Color scheme standards
- [COSMIC Desktop](https://github.com/pop-os/cosmic-epoch) - COSMIC desktop environment

## See Also

- [`MODULES.md`](MODULES.md) - Complete module system documentation
- [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) - General NixOS troubleshooting guide
