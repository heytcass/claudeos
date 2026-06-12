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

The theme system is split across two layers following NixOS best practices:

### 1. `modules/desktop/theme.nix` (NixOS System-Level)

**Purpose:** System-wide Stylix configuration and base16 color scheme

**Responsibilities:**
- Defines the base16 color palette
- Enables Stylix for system-level theming
- Sets the wallpaper (`assets/chicago.jpg`, fill scaling)
- Configures cursor theme (Adwaita, size 20)
- Configures font families (Inter, JetBrains Mono Nerd Font, Noto Serif, Noto Color Emoji)
- Sets polarity (dark mode)
- Configures Qt theming (adwaita-dark via gtk2 platform)

XDG portals are provided and configured by GNOME itself (xdg-desktop-portal-gnome + gtk fallback) — no manual wiring.

**Why system-level:** Color schemes and Stylix foundation need to be available at boot and for system services. Because home-manager runs as a NixOS module, Stylix's home-manager targets (Ghostty, VS Code, fzf, bat, lazygit, GTK, ...) follow automatically from the system-level config — there is no separate per-target enable file anymore.

### 2. `home/gnome.nix` (Home Manager)

**Purpose:** GNOME user preferences via dconf

**Responsibilities:**
- Sets `color-scheme = "prefer-dark"` so GNOME and libadwaita apps follow the dark polarity
- Input sources (Colemak), idle/lock policy, Claude keybindings

GNOME's own shell handles wallpaper rendering, lock screen, and notifications — the old Noctalia Material-token mapping is gone.

Several consumers read the generated Stylix palette at runtime instead of being themed at build time: `claude-statusline` and the `claudeos` help command read `~/.config/stylix/palette.json`, and the morning-desk agent receives the palette JSON in its prompt.

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

Adwaita is GNOME's native icon theme, so no extra configuration is needed — GNOME ships and uses it by default. `lib/theme.nix` keeps the icon name (`icons.name = "Adwaita"`) centralized as data. `modules/desktop/gnome.nix` adds two custom hicolor SVGs that the stock theme lacks: `tab-new-symbolic` (for Ghostty's libadwaita tab bar, removed from adwaita-icon-theme in GNOME 46+) and `folder-development` (for ~/Projects).

## Cursor Theme

**Package:** `pkgs.adwaita-icon-theme`
**Name:** `Adwaita`
**Size:** `20`

Stylix manages the cursor theme via `stylix.cursor` in `modules/desktop/theme.nix`. Setting all three properties (package, name, size) causes Stylix to configure `home.pointerCursor`, which sets `XCURSOR_SIZE` and `XCURSOR_THEME` environment variables. These are picked up by GNOME and all Wayland/X11 applications.

### Implementation Details

**System level (theme.nix):**
```nix
stylix.cursor = {
  package = pkgs.adwaita-icon-theme;
  name = "Adwaita";
  size = 20;
};
```

This single declaration drives cursor theming across the entire desktop -- GNOME, GTK apps, Qt apps, and Electron apps all inherit the cursor settings.

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
- Adwaita (GNOME default) plus custom hicolor SVG additions
- Symbolic icon support for modern applications

### Layer 3: GNOME Desktop Integration
- `color-scheme = "prefer-dark"` in dconf (`home/gnome.nix`) so GNOME Shell and libadwaita apps follow the dark polarity
- Runtime palette consumers: `claude-statusline`, `claudeos`, morning-desk dashboard

## Testing

### Visual Validation Checklist

**Stylix theming:**
- [ ] GTK apps display terracotta accent colors
- [ ] Ghostty terminal uses base16 color scheme
- [ ] VS Code shows themed interface
- [ ] Check syntax highlighting in terminal and editors

**Desktop settings:**
- [ ] Dark mode active system-wide (GNOME Shell + libadwaita apps)
- [ ] Wallpaper set from `assets/chicago.jpg`
- [ ] Icon consistency across applications
- [ ] Cursor theme (Adwaita) consistent across apps

**Integration:**
- [ ] Terminal and GUI apps feel cohesive
- [ ] `claude-statusline` and `claudeos` output use palette colors
- [ ] Morning desk dashboard matches the base16 palette

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

Rebuild and log out/in to apply changes. Anything that reads `config.lib.stylix.colors` or the generated palette JSON updates automatically.

### Changing Icon Theme

GNOME uses Adwaita by default. To switch, set the icon theme via dconf (`org/gnome/desktop/interface` `icon-theme`) in `home/gnome.nix` and install the theme package. Also update `lib/theme.nix` to keep the icon name centralized:

```nix
icons = {
  name = "Your-Theme-Name";
};
```

### Adjusting Stylix Targets

With home-manager running as a NixOS module, Stylix auto-enables its supported targets. To disable one (e.g. if it fights an app's own theming), set `stylix.targets.<name>.enable = false` in a home-manager module. See the Stylix documentation for the full target list.

## Troubleshooting

### GTK Apps Not Themed

**Symptom:** Some GTK applications ignore Stylix theming

**Solution:**
1. Check that the app is supported by Stylix (libadwaita apps follow the GNOME dark preference, not base16 CSS)
2. Verify dark mode is set in dconf (configured in `home/gnome.nix`):
```nix
dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
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
rebuild
```

## Import Structure

### NixOS Configuration

`modules/desktop/theme.nix` is imported via `modules/desktop/default.nix`, which every host receives through `lib/mkSystem.nix`:

```nix
imports = [
  ./gnome.nix
  ./audio.nix
  ./fonts.nix
  ./theme.nix
];
```

### Home Manager Configuration

In `home/default.nix`:

```nix
imports = [
  ./gnome.nix     # dconf: dark mode, input, keybindings
  ./ghostty.nix
  ./vscode.nix
  # other modules
];
```

## Dependencies

**System packages required:**
- `pkgs.adwaita-icon-theme` - Cursor theme package
- `pkgs.inter` - Sans-serif font
- `pkgs.nerd-fonts.jetbrains-mono` - Monospace font
- `pkgs.noto-fonts` - Serif font
- `pkgs.noto-fonts-color-emoji` - Emoji font

**NixOS modules:**
- Stylix (configured at system level; home-manager targets follow automatically)
- Home Manager (runs as a NixOS module)

## References

- [Stylix Documentation](https://nix-community.github.io/stylix/) - Official Stylix theming engine docs
- [Adwaita Icon Theme](https://gitlab.gnome.org/GNOME/adwaita-icon-theme) - Icon theme repository
- [libadwaita CSS Variables](https://gnome.pages.gitlab.gnome.org/libadwaita/doc/1.2/css-variables.html) - CSS customization reference
- [Base16 Styling Guidelines](https://github.com/chriskempson/base16/blob/main/styling.md) - Color scheme standards

## See Also

- [`MODULES.md`](MODULES.md) - Complete module system documentation
- [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) - General NixOS troubleshooting guide
