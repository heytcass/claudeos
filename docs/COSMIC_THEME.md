# COSMIC Theme Integration

## Overview

COSMIC Desktop Environment uses its own configuration system that is separate from standard freedesktop specifications. As a result, Stylix does not currently support COSMIC theming (see [stylix issue #265](https://github.com/nix-community/stylix/issues/265)).

This configuration provides manual COSMIC theme integration that:
- Maps Stylix base16 colors to COSMIC's theme format
- Sets the Claude wallpaper as COSMIC background
- Configures accent colors, backgrounds, and interface elements

## Configuration

The COSMIC theme integration is implemented in `home/cosmic-theme.nix` and consists of two parts:

### 1. Theme Configuration (`~/.config/cosmic/com.system76.CosmicTheme.Dark/v1/custom_theme`)

Maps Stylix base16 colors to COSMIC's RON (Rusty Object Notation) format:

| Stylix Base16 | COSMIC Theme Element |
|---------------|---------------------|
| base00 | Background color (`bg_color`) |
| base01 | Primary container background |
| base02 | Secondary container background |
| base03-06 | Neutral grayscale ramp |
| base08 | Accent color (terracotta), destructive actions, red |
| base09 | Orange accent |
| base0A | Yellow accent, warnings |
| base0B | Green accent, success states |
| base0C | Cyan accent |
| base0D | Blue accent |
| base0E | Purple/magenta accent |

### 2. Wallpaper Configuration (`~/.config/cosmic/com.system76.CosmicBackground/v1/all`)

Sets the COSMIC wallpaper to the Stylix image:
- Source: `assets/claude.png` (via `config.stylix.image`)
- Scaling mode: Fit
- Filter method: Lanczos

## COSMIC Settings Mapped

The following COSMIC appearance settings are configured from Stylix:

- **Window Background**: `bg_color` (base00)
- **Container Background**: `primary_container_bg` (base01)
- **Secondary Container**: `secondary_container_bg` (base02)
- **Interface Text Tint**: Uses neutral grayscale
- **Control Component Tint**: Managed by neutral colors
- **Accent Color**: Terracotta (base08 - #c6613f)
- **Success/Warning/Destructive**: Green/Yellow/Red from base16

## Changing the Accent Color

The accent color is currently set to terracotta (base08). To change it:

1. Edit `home/cosmic-theme.nix`
2. Find the line: `accent: Some${formatRgb c08},`
3. Change `c08` to a different color variable:
   - `c08`: Terracotta (default)
   - `c09`: Lighter terracotta/orange
   - `c0A`: Warm sand/yellow
   - `c0B`: Olive green
   - `c0C`: Sage cyan
   - `c0D`: Link blue
   - `c0E`: Warm brown/magenta

## Applying Changes

After modifying the configuration:

```bash
# On the target machine
cd ~/.config/claudeos
sudo nixos-rebuild switch --flake .#$(hostname)

# Log out and back in to COSMIC for changes to take effect
```

## Future Improvements

When Stylix gains COSMIC support, this manual configuration can be replaced with:

```nix
stylix.targets.cosmic.enable = true;
```

## References

- [COSMIC Desktop Theming Guide](https://system76.com/cosmic/theming)
- [System76 COSMIC Blog](https://blog.system76.com/post/customizing-cosmic-theming-and-applications/)
- [Stylix COSMIC Support Issue](https://github.com/nix-community/stylix/issues/265)
- [COSMIC Themes Repository](https://github.com/iamkartiknayak/cosmic-themes)
