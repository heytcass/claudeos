# Theme System

Comprehensive visual theme system built on Stylix base16 implementation. Creates a cohesive Claude-branded desktop environment with warm terracotta accent colors across applications.

## Overview

The ClaudeOS theme system uses Stylix's powerful base16 theming to create a consistent visual experience across the desktop environment. The theme features:

- **Custom color scheme** based on Claude's brand colors (warm terracotta accent)
- **Adwaita icon theme** for GTK/libadwaita applications
- **Adwaita cursor theme** managed by Stylix (size 20)
- **Dark mode by default** with system-wide consistency
- **100+ applications themed** via Stylix targets

## Architecture

The theme system is split across two modules following NixOS best practices:

### 1. `modules/desktop/theme.nix` (NixOS System-Level)

**Purpose:** System-wide Stylix configuration and base16 color scheme

**Responsibilities:**
- Defines the base16 color palette
- Enables Stylix for system-level theming
- Configures cursor theme (Adwaita, size 20)
- Configures font families (Inter, JetBrains Mono, Noto Serif, Noto Color Emoji)
- Sets polarity (dark mode)
- Configures Qt theming (adwaita-dark via gtk2 platform)
- Sets up XDG portal (xdg-desktop-portal-gtk)

**Why system-level:** Color schemes and Stylix foundation need to be available at boot and for system services.

### 2. `home/niri.nix` (Home Manager)

**Purpose:** User-level Stylix targets, GTK configuration, and Niri/Noctalia desktop integration

**Responsibilities:**
- Enables Stylix targets for specific applications (Ghostty, VS Code, Firefox, fzf, bat, lazygit, niri, fuzzel)
- Configures GTK icon theme (Adwaita) and dark mode preferences
- Maps Stylix base16 colors to Noctalia Material Design color tokens
- Manages dconf settings for GTK application dark mode compatibility
- Configures Niri compositor layout, keybindings, and window rules
- Configures Noctalia Shell (bar, notifications, OSD, wallpaper, lock screen, launcher)

**Why Home Manager:** Application-specific theming and compositor configuration belong in the user session, not system-wide.

## Color Scheme

The ClaudeOS base16 scheme uses warm, earthy tones extracted from live claude.ai CSS tokens:

```nix
base16Scheme = {
  base00 = "1f1e1d"; # --bg-200  — deepest background
  base01 = "262624"; # --bg-100  — main body background
  base02 = "30302e"; # --bg-000  — elevated surface (input box, cards)
  base03 = "9c9a92"; # --text-400 — muted text / placeholders
  base04 = "c2c0b6"; # --text-200 — secondary text
  base05 = "faf9f5"; # --text-100 — primary text
  base06 = "faf9f5"; # --text-000 — bright text
  base07 = "ffffff"; # --oncolor-100 — pure white

  base08 = "c6613f"; # --accent-main-000 — dark terracotta (errors, destructive)
  base09 = "e6956b"; # Warm peach — lighter accent for constants/highlights
  base0A = "c9b87c"; # Warm sand — warnings, classes
  base0B = "8a9a6b"; # Muted olive — success, strings
  base0C = "2c84db"; # --accent-secondary-100 — blue (info, links, secondary accent)
  base0D = "d97757"; # --accent-brand — TERRACOTTA (primary accent, functions, borders)
  base0E = "a67a5b"; # Warm brown — keywords, special
  base0F = "bd5d3a"; # Deep terracotta — hover state, embedded
};
```

**Design philosophy:**
- Warm neutrals (browns, grays) for backgrounds
- Terracotta (`#d97757` / base0D) as the primary accent color
- Muted earth tones for semantic colors (green, yellow)
- Bright blue (`#2c84db` / base0C) preserved for links and information states

## Icon Theme

**Package:** `pkgs.adwaita-icon-theme`

**Variant:** Adwaita (standard icon theme for GTK/libadwaita)

Adwaita provides symbolic icons that integrate well with GTK applications and the modern libadwaita design language. Niri and Noctalia use their own rendering, but GTK applications respect this theme setting via the `gtk.iconTheme` configuration in `home/niri.nix`.

### Implementation Details

**System level (theme.nix):**
```nix
# Icon theme package is implicitly available via Stylix
```

**Home Manager (niri.nix):**
```nix
gtk.iconTheme = {
  name = "Adwaita";
  package = pkgs.adwaita-icon-theme;
};
```

## Cursor Theme

**Package:** `pkgs.adwaita-icon-theme`
**Name:** `Adwaita`
**Size:** `20`

Stylix manages the cursor theme via `stylix.cursor` in `modules/desktop/theme.nix`. Setting all three properties (package, name, size) causes Stylix to configure `home.pointerCursor`, which sets `XCURSOR_SIZE` and `XCURSOR_THEME` environment variables. These are picked up by Niri and all Wayland/X11 applications.

### Implementation Details

**System level (theme.nix):**
```nix
stylix.cursor = {
  package = pkgs.adwaita-icon-theme;
  name = "Adwaita";
  size = 20;
};
```

This single declaration drives cursor theming across the entire desktop -- Niri, GTK apps, Qt apps, and Electron apps all inherit the cursor settings.

## Configuration Layers

The theme system builds up in three distinct layers:

### Layer 1: Stylix Foundation
- Base16 color scheme definition
- Automatic CSS generation for GTK3/GTK4
- System-wide application theming (100+ apps)
- Terminal color schemes
- Cursor theme (Adwaita, size 20)
- Font configuration (Inter, JetBrains Mono, Noto Serif, Noto Color Emoji)

### Layer 2: Icon Theme
- Adwaita package installation
- GTK icon theme configuration
- Symbolic icon support for modern applications

### Layer 3: Niri/Noctalia Desktop Integration
- Niri compositor border colors derived from Stylix
- Noctalia Shell Material Design color tokens mapped from base16 palette
- GTK dark mode preference enforcement via gtk3/gtk4 extraConfig
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
- [ ] Niri border colors match Stylix palette
- [ ] Noctalia bar colors match Stylix palette
- [ ] GTK applications integrate well with Niri
- [ ] Icon consistency across applications
- [ ] Cursor theme (Adwaita) consistent across apps

**Integration:**
- [ ] Smooth color transitions in applications
- [ ] Terminal and GUI apps feel cohesive
- [ ] No visual conflicts between Stylix CSS and Noctalia templates
- [ ] Fuzzel launcher colors derived from Stylix

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

Rebuild and log out/in to apply changes. Noctalia colors in `home/niri.nix` are derived from `config.lib.stylix.colors.withHashtag` so they update automatically.

### Changing Icon Theme

Edit `modules/desktop/theme.nix` (if using Stylix icons) and `home/niri.nix`:

```nix
# In niri.nix
gtk.iconTheme = {
  name = "Your-Theme-Name";
  package = pkgs.your-icon-theme;
};
```

Also update `lib/theme.nix` to keep the icon name centralized:

```nix
icons = {
  name = "Your-Theme-Name";
};
```

### Adding Stylix Targets

Edit `home/niri.nix`:

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
1. Verify Stylix targets are enabled in `home/niri.nix`
2. Check that the app is supported by Stylix
3. Verify dark mode is set in dconf (this is configured in `home/niri.nix`):
```nix
dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
```
4. Check that `xdg.configFile` force-overwrite is active for GTK CSS files

### Icons Not Appearing Correctly

**Symptom:** Missing or incorrect icons in applications

**Solution:**
```bash
# Rebuild icon cache
gtk-update-icon-cache ~/.icons/Adwaita

# Verify icon theme package is installed
nix-store -q --references ~/.nix-profile | grep adwaita-icon-theme
```

### Cursor Theme in Electron Apps

**Symptom:** Cursor looks different in VS Code or Claude Desktop

**Current state:** The Adwaita cursor theme is set system-wide at size 20 via `stylix.cursor` in `modules/desktop/theme.nix`. This sets `XCURSOR_SIZE` and `XCURSOR_THEME` for all applications. However, Electron apps may still use their own cursor rendering in some cases, which can cause minor visual differences.

**Workaround:** If an Electron app shows a different cursor, check that it is launched with Wayland support (`--ozone-platform=wayland`), as X11/XWayland mode can cause cursor inconsistencies.

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

In the system builder (`lib/mkSystem.nix`), `modules/desktop/theme.nix` is imported as part of the common module set:

```nix
imports = [
  ../../modules/desktop/theme.nix
  # other modules
];
```

### Home Manager Configuration

In `home/default.nix`:

```nix
imports = [
  ./niri.nix      # Stylix targets, GTK config, Niri + Noctalia
  ./ghostty.nix
  ./vscode.nix
  # other modules
];
```

## Dependencies

**System packages required:**
- `pkgs.adwaita-icon-theme` - Icon and cursor theme package
- `pkgs.inter` - Sans-serif font
- `pkgs.jetbrains-mono` - Monospace font
- `pkgs.noto-fonts` - Serif font
- `pkgs.noto-fonts-color-emoji` - Emoji font

**NixOS modules:**
- Stylix (configured at system level)
- Home Manager (for user-level theming)

**Flake inputs:**
- `niri-flake` - Auto-imports niri + stylix home modules
- `noctalia` - Shell, bar, notifications, OSD, wallpaper

## References

- [Stylix Documentation](https://nix-community.github.io/stylix/) - Official Stylix theming engine docs
- [Adwaita Icon Theme](https://gitlab.gnome.org/GNOME/adwaita-icon-theme) - Icon theme repository
- [libadwaita CSS Variables](https://gnome.pages.gitlab.gnome.org/libadwaita/doc/1.2/css-variables.html) - CSS customization reference
- [Base16 Styling Guidelines](https://github.com/chriskempson/base16/blob/main/styling.md) - Color scheme standards
- [Niri Compositor](https://github.com/YaLTeR/niri) - Scrollable tiling Wayland compositor
- [Noctalia Shell](https://github.com/nicholasgasior/noctalia) - Desktop shell (bar, notifications, OSD, wallpaper)

## See Also

- [`MODULES.md`](MODULES.md) - Complete module system documentation
- [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) - General NixOS troubleshooting guide
