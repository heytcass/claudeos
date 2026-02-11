# GNOME Theme System

Comprehensive GNOME visual theme with Papirus icons, custom accent colors, and Shell customization. Built on Stylix base16 implementation to create a cohesive Claude-branded desktop environment.

## Overview

The ClaudeOS theme system combines Stylix's powerful base16 theming with GNOME-specific customizations to create a consistent visual experience across the desktop environment. The theme features:

- **Custom color scheme** based on Claude's brand colors (warm terracotta accent)
- **Papirus icon theme** with terracotta-brown folder colorization
- **GNOME accent color integration** using a hybrid approach
- **Dark mode by default** with system-wide consistency
- **100+ applications themed** via Stylix targets

## Architecture

The theme system is split across three modules following NixOS best practices:

### 1. `modules/desktop/theme.nix` (NixOS System-Level)

**Purpose:** System-wide Stylix configuration and base16 color scheme

**Responsibilities:**
- Defines the base16 color palette
- Enables Stylix for system-level theming
- Configures icon theme package (Papirus)
- Sets polarity (dark mode)

**Why system-level:** Color schemes and Stylix foundation need to be available at boot and for system services (e.g., GDM login screen).

### 2. `modules/desktop/theme-home.nix` (Home Manager)

**Purpose:** User-level Stylix targets and icon customization

**Responsibilities:**
- Enables Stylix for specific applications (Ghostty, VS Code, Firefox, etc.)
- Runs Papirus folder colorization script on activation
- Provides GTK CSS override hooks if needed

**Why Home Manager:** Application-specific theming belongs in the user session, not system-wide. Icon colorization is a user preference.

### 3. `modules/desktop/gnome.nix` (Home Manager)

**Purpose:** GNOME-specific settings via dconf and GTK configuration

**Responsibilities:**
- Sets GNOME accent color (via dconf)
- Configures GTK icon theme and dark mode preferences
- Manages GNOME Shell and interface settings

**Why separate:** GNOME configuration is independent of Stylix and may need frequent adjustments. Keeping it separate makes changes easier.

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

## Hybrid Accent Color Approach

### The Problem

GNOME 47+ accent colors are restricted to 9 enum presets:
- `blue`, `teal`, `green`, `yellow`, `orange`, `red`, `pink`, `purple`, `slate`

The accent-color dconf setting accepts **only these enum values**, not custom hex colors. This is a schema-level limitation in libadwaita.

### The Solution

We use a **hybrid approach** that provides visual consistency while working within GNOME's constraints:

1. **GNOME accent set to "orange"** (`#ed5b00`)
   - Closest available preset to our terracotta (`#c6613f`)
   - Applied to: Shell UI, system dialogs, libadwaita native widgets

2. **Stylix CSS provides exact terracotta** in GTK apps
   - Applied to: GTK3/GTK4 applications, custom widgets, CSS-based themes
   - Overrides libadwaita's orange with our precise brand color

**Color difference:** ~15% between GNOME's orange and our terracotta
- In practice: Barely noticeable due to adaptive color blending in libadwaita
- Shell chrome uses orange, app content uses terracotta
- Creates visual harmony without being identical

**Why not custom GNOME Shell theme?**
- Requires User Themes extension (fragile, conflicts in GNOME 49)
- Shell theme maintenance burden is high
- Stylix handles GTK theming better than custom Shell CSS
- Stability over perfect color matching

## Icon Theme

### Papirus Integration

**Package:** `pkgs.papirus-icon-theme`

**Variant:** Papirus-Dark (optimized for dark backgrounds)

**Folder colorization:**
```bash
papirus-folders -C brown --theme Papirus-Dark
```

This command recolors all folder icons to a warm brown tone that complements the terracotta accent.

### Implementation Details

**System level (theme.nix):**
```nix
stylix.icons = {
  enable = true;
  package = pkgs.papirus-icon-theme;
};
```

**Home Manager (gnome.nix):**
```nix
gtk.iconTheme = {
  name = "Papirus-Dark";
  package = pkgs.papirus-icon-theme;
};
```

**Activation script (theme-home.nix):**
```nix
home.activation.papirus-folders = lib.hm.dag.entryAfter ["writeBoundary"] ''
  ${pkgs.papirus-folders}/bin/papirus-folders -C brown --theme Papirus-Dark
'';
```

The activation script runs on every Home Manager activation, ensuring folder colors remain consistent even after icon theme updates.

## Configuration Layers

The theme system builds up in four distinct layers:

### Layer 1: Stylix Foundation
- Base16 color scheme definition
- Automatic CSS generation for GTK3/GTK4
- GNOME Shell theme package replacement
- System-wide application theming (100+ apps)

### Layer 2: Icon Theme
- Papirus-Dark package installation
- Folder icon colorization to brown/terracotta
- Home Manager activation script for persistence

### Layer 3: GNOME Integration
- Accent color set to "orange" (closest to terracotta)
- Dark mode preference enforcement
- Built-in rounded corners (GNOME 47+ feature)
- dconf settings for desktop interface

### Layer 4: Excluded Elements
- **No cursor theme** - Electron apps (VS Code, Claude Desktop) often override cursor themes, causing inconsistency
- **No heavy extensions** - Stability prioritized over visual effects
- **No User Themes extension** - Package conflicts in GNOME 49, Stylix handles Shell theming

## Testing

### Visual Validation Checklist

**Stylix theming:**
- [ ] GTK apps display terracotta accent colors
- [ ] Ghostty terminal uses base16 color scheme
- [ ] VS Code shows themed interface
- [ ] Firefox themed (toolbars, menus)
- [ ] Check syntax highlighting in terminal and editors

**GNOME settings:**
- [ ] Settings → Appearance shows "orange" accent selected
- [ ] Dark mode active system-wide
- [ ] Rounded corners visible on windows (GNOME 47+ built-in)
- [ ] Shell UI elements use orange accent

**Papirus icons:**
- [ ] Folder icons display brown/terracotta tone
- [ ] Application icons use Papirus-Dark variants
- [ ] Icon consistency across Files, launcher, and dash

**Integration:**
- [ ] No visual conflicts between Stylix CSS and GNOME accent
- [ ] Smooth color transitions in libadwaita apps
- [ ] Terminal and GUI apps feel cohesive

### Discovery Workflow

To capture additional GNOME preferences dynamically:

```bash
# Open a terminal and start watching dconf changes
dconf watch /

# In GNOME Settings, change preferences
# Example: adjust font scaling, enable night light, etc.

# Copy the dconf paths from the watch output
# Convert to Nix format using dconf2nix
dconf dump / | dconf2nix > new-settings.nix

# Add desired settings to modules/desktop/gnome.nix
```

This workflow is useful for:
- Discovering hidden GNOME settings
- Capturing user preference changes
- Converting manual tweaks into reproducible config

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

Rebuild and restart GNOME Shell (Alt+F2, type `r`, press Enter).

### Adjusting GNOME Accent

Edit `modules/desktop/gnome.nix`:

```nix
dconf.settings."org/gnome/desktop/interface" = {
  accent-color = "purple";  # Choose from: blue, teal, green, yellow, orange, red, pink, purple, slate
};
```

### Changing Icon Theme

Edit `modules/desktop/theme.nix` and `modules/desktop/gnome.nix`:

```nix
# In theme.nix
stylix.icons.package = pkgs.your-icon-theme;

# In gnome.nix
gtk.iconTheme = {
  name = "Your-Theme-Name";
  package = pkgs.your-icon-theme;
};
```

Remove or adjust the `papirus-folders` activation script in `theme-home.nix` if not using Papirus.

### Adding Stylix Targets

Edit `modules/desktop/theme-home.nix`:

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

### Icons Not Changing

**Symptom:** Folder icons remain default blue after rebuild

**Solution:**
```bash
# Manually run the colorization script
papirus-folders -C brown --theme Papirus-Dark

# Restart GNOME Shell
Alt+F2, type 'r', press Enter
```

**Persistent issues:** Check that `pkgs.papirus-folders` is installed and in PATH.

### GNOME Accent Color Not Applied

**Symptom:** Accent color in Settings shows a different value

**Solution:**
```bash
# Check current dconf value
dconf read /org/gnome/desktop/interface/accent-color

# Manually set if needed
dconf write /org/gnome/desktop/interface/accent-color "'orange'"

# Verify config is being applied
home-manager generations | head -n 5
```

**Common cause:** Conflicting dconf settings in other Home Manager modules.

### GTK Apps Not Themed

**Symptom:** Some GTK applications ignore Stylix theming

**Solution:**
1. Verify Stylix targets are enabled in `theme-home.nix`
2. Check that the app is supported by Stylix
3. Force GTK4 apps to prefer dark theme:
```bash
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
```

### Cursor Theme Issues with Electron

**Symptom:** Cursor looks different in VS Code or Claude Desktop

**Expected behavior:** Electron apps often override cursor themes. This is why we don't configure a custom cursor theme - it would be inconsistent anyway.

**Workaround:** Accept default cursor in Electron apps, or configure per-app if really needed.

### Stylix Overriding GNOME Settings

**Symptom:** GNOME Settings changes get reverted after rebuild

**Cause:** Stylix manages GTK and GNOME Shell themes, which can override manual changes.

**Solution:**
- Add desired settings to `gnome.nix` dconf configuration
- Use dconf watch to discover the correct paths
- Keep theme configuration declarative in Nix

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
sudo nixos-rebuild switch --flake .#transporter
```

The feature branch remains intact for debugging and can be rebased/fixed without affecting the main configuration.

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

In your Home Manager config (e.g., `home-manager/tom/home.nix`):

```nix
imports = [
  ../../modules/desktop/theme-home.nix
  ../../modules/desktop/gnome.nix
  # other modules
];
```

## Dependencies

**System packages required:**
- `pkgs.papirus-icon-theme` - Icon theme package
- `pkgs.papirus-folders` - Folder colorization utility

**NixOS modules:**
- Stylix (configured at system level)
- Home Manager (for user-level theming)

**No GNOME extensions required** - All features use GNOME 47+ built-in capabilities (rounded corners, accent colors, dark mode).

## References

- [Stylix Documentation](https://nix-community.github.io/stylix/) - Official Stylix theming engine docs
- [Papirus Icon Theme](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme) - Icon theme repository
- [GNOME 47 Accent Colors](https://release.gnome.org/47/) - Release notes for accent color feature
- [libadwaita CSS Variables](https://gnome.pages.gitlab.gnome.org/libadwaita/doc/1.2/css-variables.html) - CSS customization reference
- [Base16 Styling Guidelines](https://github.com/chriskempson/base16/blob/main/styling.md) - Color scheme standards
- [dconf2nix](https://github.com/gvolpe/dconf2nix) - Tool for converting dconf dumps to Nix

**Research citations:**
- Stylix GNOME capabilities (agentId: a77caf8)
- NixOS theme organization patterns (agentId: a3f6716)
- GNOME custom accent colors (agentId: a032f3b)

## See Also

- [`MODULES.md`](MODULES.md) - Complete module system documentation
- [`CLAUDE-DEVELOPMENT.md`](CLAUDE-DEVELOPMENT.md) - Development workflow and build process
- [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) - General NixOS troubleshooting guide
