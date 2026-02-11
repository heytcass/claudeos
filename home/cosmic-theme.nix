{ config, lib, pkgs, ... }:

let
  # Helper function to convert hex digit to int
  hexDigitToInt = digit:
    let
      digits = {
        "0" = 0;
        "1" = 1;
        "2" = 2;
        "3" = 3;
        "4" = 4;
        "5" = 5;
        "6" = 6;
        "7" = 7;
        "8" = 8;
        "9" = 9;
        "a" = 10;
        "b" = 11;
        "c" = 12;
        "d" = 13;
        "e" = 14;
        "f" = 15;
        "A" = 10;
        "B" = 11;
        "C" = 12;
        "D" = 13;
        "E" = 14;
        "F" = 15;
      };
    in
    digits.${digit};

  # Helper function to convert two hex digits to int
  hexToInt = hex:
    let
      high = builtins.substring 0 1 hex;
      low = builtins.substring 1 1 hex;
    in
    (hexDigitToInt high) * 16 + (hexDigitToInt low);

  # Helper function to convert hex color to COSMIC RGB format (0.0-1.0 range)
  hexToRgb = hex:
    let
      r = hexToInt (builtins.substring 0 2 hex);
      g = hexToInt (builtins.substring 2 2 hex);
      b = hexToInt (builtins.substring 4 2 hex);
    in
    {
      red = r / 255.0;
      green = g / 255.0;
      blue = b / 255.0;
    };

  # Helper to format RGB for COSMIC RON format (with alpha)
  formatRgba = rgb: ''
    (
                red: ${toString rgb.red},
                green: ${toString rgb.green},
                blue: ${toString rgb.blue},
                alpha: 1.0,
            )'';

  # Helper to format RGBA for Some((tuple)) format
  formatRgbaSome = rgb: ''
    ((
            red: ${toString rgb.red},
            green: ${toString rgb.green},
            blue: ${toString rgb.blue},
            alpha: 1.0,
        ))'';

  # Helper to format RGB without alpha (for Some((tuple)) format)
  formatRgb = rgb: ''
    ((
            red: ${toString rgb.red},
            green: ${toString rgb.green},
            blue: ${toString rgb.blue},
        ))'';

  # Extract colors from Stylix base16 scheme
  scheme = config.stylix.base16Scheme;

  # Convert all base16 colors
  c00 = hexToRgb scheme.base00;
  c01 = hexToRgb scheme.base01;
  c02 = hexToRgb scheme.base02;
  c03 = hexToRgb scheme.base03;
  c04 = hexToRgb scheme.base04;
  c05 = hexToRgb scheme.base05;
  c06 = hexToRgb scheme.base06;
  c07 = hexToRgb scheme.base07;
  c08 = hexToRgb scheme.base08; # red/terracotta
  c09 = hexToRgb scheme.base09; # orange
  c0A = hexToRgb scheme.base0A; # yellow
  c0B = hexToRgb scheme.base0B; # green
  c0C = hexToRgb scheme.base0C; # cyan
  c0D = hexToRgb scheme.base0D; # blue (primary accent)
  c0E = hexToRgb scheme.base0E; # magenta
  c0F = hexToRgb scheme.base0F; # brown

  # Custom destructive red — intentionally more vivid than base08 terracotta
  cDestructive = hexToRgb "dd5353";

  # Complete COSMIC theme in export format
  claudeTheme = pkgs.writeText "Claude.ron" ''
    (
        palette: Dark((
            name: "Claude",
            bright_red: ${formatRgba c08},
            bright_green: ${formatRgba c0B},
            bright_orange: ${formatRgba c09},
            gray_1: ${formatRgba c01},
            gray_2: ${formatRgba c02},
            neutral_0: ${formatRgba c00},
            neutral_1: ${formatRgba c00},
            neutral_2: ${formatRgba c01},
            neutral_3: ${formatRgba c02},
            neutral_4: ${formatRgba c03},
            neutral_5: ${formatRgba c03},
            neutral_6: ${formatRgba c04},
            neutral_7: ${formatRgba c05},
            neutral_8: ${formatRgba c05},
            neutral_9: ${formatRgba c06},
            neutral_10: ${formatRgba c07},
            accent_blue: ${formatRgba c0D},
            accent_indigo: ${formatRgba c0E},
            accent_purple: ${formatRgba c0E},
            accent_pink: ${formatRgba c08},
            accent_red: ${formatRgba c08},
            accent_orange: ${formatRgba c09},
            accent_yellow: ${formatRgba c0A},
            accent_green: ${formatRgba c0B},
            accent_warm_grey: ${formatRgba c03},
            ext_warm_grey: ${formatRgba c03},
            ext_orange: ${formatRgba c09},
            ext_yellow: ${formatRgba c0A},
            ext_blue: ${formatRgba c0D},
            ext_purple: ${formatRgba c0E},
            ext_pink: ${formatRgba c08},
            ext_indigo: ${formatRgba c0D},
        )),
        spacing: (
            space_none: 0,
            space_xxxs: 4,
            space_xxs: 8,
            space_xs: 12,
            space_s: 16,
            space_m: 24,
            space_l: 32,
            space_xl: 48,
            space_xxl: 64,
            space_xxxl: 128,
        ),
        corner_radii: (
            radius_0: (0.0, 0.0, 0.0, 0.0),
            radius_xs: (6.0, 6.0, 6.0, 6.0),
            radius_s: (8.0, 8.0, 8.0, 8.0),
            radius_m: (12.0, 12.0, 12.0, 12.0),
            radius_l: (20.0, 20.0, 20.0, 20.0),
            radius_xl: (160.0, 160.0, 160.0, 160.0),
        ),
        neutral_tint: Some${formatRgb c0A},
        bg_color: Some${formatRgbaSome c00},
        primary_container_bg: Some${formatRgbaSome c02},
        secondary_container_bg: Some${formatRgbaSome c00},
        text_tint: None,
        accent: Some${formatRgb c08},
        success: Some${formatRgb c0B},
        warning: Some${formatRgb c0A},
        destructive: Some${formatRgb cDestructive},
        is_frosted: false,
        gaps: (0, 4),
        active_hint: 2,
        window_hint: None,
    )
  '';
  # COSMIC wallpaper configuration
  cosmicWallpaperConfig = pkgs.writeText "cosmic-wallpaper.ron" ''
    (
        output: "all",
        source: Path("${config.stylix.image}"),
        filter_by_theme: false,
        rotation_frequency: 300,
        filter_method: Lanczos,
        scaling_mode: Zoom,
        sampling_method: Alphanumeric,
    )
  '';
in
{
  # Import theme into COSMIC's custom theme location
  # This activates the theme instead of just providing a reference file
  home.file.".config/cosmic/com.system76.CosmicTheme.Dark/v1/custom_theme".source = claudeTheme;

  # Set the Claude wallpaper for COSMIC using activation script
  # This ensures the wallpaper config is written after COSMIC's config directory exists
  home.activation.cosmicWallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p ${config.home.homeDirectory}/.config/cosmic/com.system76.CosmicBackground/v1
    $DRY_RUN_CMD install -m 644 ${cosmicWallpaperConfig} ${config.home.homeDirectory}/.config/cosmic/com.system76.CosmicBackground/v1/all
  '';
}
