{
  config,
  lib,
  pkgs,
  ...
}:

let
  themeLib = import ../../lib/theme.nix;

  sedArgsFor =
    subs: lib.concatStringsSep " " (lib.mapAttrsToList (from: to: "-e 's/${from}/${to}/gI'") subs);

  # Nautilus folder icons: Adwaita hardcodes a blue ramp in its places icons
  # (no accent-color integration at all). Overlaying adwaita-icon-theme would
  # rebuild half of GNOME, so instead ship a tiny "ClaudeOS" icon theme that
  # inherits Adwaita and overrides only the places icons, recolored onto the
  # terracotta ramp.
  folderIconSubstitutions = with config.lib.stylix.colors.withHashtag; {
    "#62a0ea" = base0D; # folder body
    "#438de6" = base0F; # folder shading / back flap
    "#c0d5ea" = base09; # gloss highlights (three near-identical pale tints)
    "#afd4ff" = base09;
    "#a4caee" = base09;
  };

  claudeosIconTheme =
    pkgs.runCommand "claudeos-icon-theme"
      {
        nativeBuildInputs = with pkgs; [
          imagemagick
          gtk3 # gtk-update-icon-cache
        ];
      }
      ''
        adwaita=${pkgs.adwaita-icon-theme}/share/icons/Adwaita
        theme=$out/share/icons/ClaudeOS
        mkdir -p "$theme/scalable/places" "$theme/16x16/places"

        for svg in "$adwaita"/scalable/places/*.svg; do
          sed ${sedArgsFor folderIconSubstitutions} "$svg" > "$theme/scalable/places/''${svg##*/}"
        done

        # folder-development (~/Projects, referenced by home/default.nix's
        # .directory file) — authored in Adwaita's blue ramp so the SAME
        # substitution recolors it onto the terracotta ramp as every other
        # folder. Body #62a0ea→base0D, flap/shading #438de6→base0F.
        cat > ./folder-development-src.svg <<'SVG'
        <svg width="256" height="256" fill="none" viewBox="0 0 256 256" xmlns="http://www.w3.org/2000/svg">
          <path d="m8 56c0-8.8366 7.1634-16 16-16h71.797c3.3814 0 6.6759 1.0713 9.4109 3.0602l13.584 9.8796c2.735 1.9889 6.029 3.0602 9.411 3.0602h103.8c8.837 0 16 7.1634 16 16v128c0 8.837-7.163 16-16 16h-208c-8.8366 0-16-7.163-16-16z" fill="#438de6"/>
          <path d="m8 88c0-8.8366 7.1634-16 16-16h208c8.837 0 16 7.1634 16 16v112c0 8.837-7.163 16-16 16h-208c-8.8366 0-16-7.163-16-16z" fill="url(#g)"/>
          <g fill="none" stroke="#fff" stroke-width="10" stroke-linecap="round" stroke-linejoin="round">
            <path d="m100 126 -20 24 20 24"/>
            <path d="m156 126 20 24-20 24"/>
            <path d="m140 114-24 72"/>
          </g>
          <defs>
            <linearGradient id="g" x1="248" x2="40.837" y1="72" y2="253.48" gradientUnits="userSpaceOnUse">
              <stop stop-color="#62a0ea"/>
              <stop stop-color="#438de6" offset="1"/>
            </linearGradient>
          </defs>
        </svg>
        SVG
        sed ${sedArgsFor folderIconSubstitutions} ./folder-development-src.svg \
          > "$theme/scalable/places/folder-development.svg"

        # Symbolic variant: a plain mask — GTK recolors it to the context
        # foreground, so no palette substitution applies.
        cat > "$theme/scalable/places/folder-development-symbolic.svg" <<'SVG'
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M1 3.5C1 2.672 1.672 2 2.5 2h3.586a1.5 1.5 0 0 1 1.06.44l.914.913a1.5 1.5 0 0 0 1.061.44H13.5c.828 0 1.5.671 1.5 1.5v6.207c0 .828-.672 1.5-1.5 1.5h-11c-.828 0-1.5-.672-1.5-1.5z" fill="#222222"/>
          <g stroke="#fff" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round">
            <path d="m6 7-1.5 1.75L6 10.5"/>
            <path d="m10 7 1.5 1.75L10 10.5"/>
            <path d="m9 6.25-2 5"/>
          </g>
        </svg>
        SVG

        # The 16x16 PNGs of the folder family are pure blue-on-alpha, so a
        # global hue rotation is fringe-free (-modulate calibrated so #62a0ea
        # lands on base0D terracotta — recalibrate if the palette changes).
        # network-* and user-trash contain other colors; omit them and let
        # icon-theme inheritance fall back to stock Adwaita.
        for png in "$adwaita"/16x16/places/folder*.png \
                   "$adwaita"/16x16/places/user-bookmarks.png \
                   "$adwaita"/16x16/places/user-desktop.png \
                   "$adwaita"/16x16/places/user-home.png; do
          magick "$png" -modulate 95,90,188 "$theme/16x16/places/''${png##*/}"
        done

        cat > "$theme/index.theme" <<EOF
        [Icon Theme]
        Name=ClaudeOS
        Comment=Adwaita with Stylix terracotta folders
        Inherits=Adwaita,hicolor

        Directories=16x16/places,scalable/places

        [16x16/places]
        Context=Places
        Size=16
        Type=Fixed

        [scalable/places]
        Context=Places
        Size=128
        MinSize=8
        MaxSize=512
        Type=Scalable
        EOF

        gtk-update-icon-cache "$theme"
      '';

in
{
  # Stylix theming with Claude brand colors
  stylix = {
    enable = true;

    # Claude.ai base16 color scheme — values extracted from live claude.ai CSS tokens
    # Backgrounds (base00–02) = --bg-200/100/000, Text (03–07) = --text-400/200/100
    # Accent hierarchy: terracotta (--accent-brand) is primary, blue (--accent-secondary) is secondary
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

    # Terracotta dune under a peach moon — ORIGINAL ClaudeOS artwork
    # (AI-generated 2026-07, sky rebuilt + upscaled to 3840² in-session; no
    # third-party rights, metadata-clean, safe to redistribute under MIT).
    # Composition: many windswept paths converging into one luminous ridgeline
    # walked by a tiny caretaker — branches merging to main, tended by lanes.
    # Sunlit dune ≈ base0D/base0F terracotta, moon ≈ base09 peach. Square 1:1
    # canvas: with imageScalingMode "fill", landscape monitors show the middle
    # horizontal band and portrait monitors the middle vertical band, both at
    # native res — key elements live in the center-safe square by design.
    # Previous: same scene by Justin Wirtalla (replaced pre-go-public — its
    # EXIF carried a third-party copyright); before that assets/chicago.jpg.
    image = ../../assets/dune.jpg;
    imageScalingMode = "fill";

    # Terracotta folder icons (see claudeosIconTheme above)
    icons = {
      enable = true;
      package = claudeosIconTheme;
      dark = "ClaudeOS";
      light = "ClaudeOS";
    };

    # Dark mode theme
    polarity = "dark";

    # Cursor theme — must set all three for Stylix to manage home.pointerCursor
    cursor = {
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
      size = 20;
    };

    # Font configuration — names and packages both from lib/theme.nix
    fonts = {
      serif = {
        package = themeLib.fonts.serif.package pkgs;
        name = themeLib.fonts.serif.name;
      };
      sansSerif = {
        package = themeLib.fonts.sansSerif.package pkgs;
        name = themeLib.fonts.sansSerif.name;
      };
      monospace = {
        package = themeLib.fonts.monospace.package pkgs;
        name = themeLib.fonts.monospace.nerdName;
      };
      emoji = {
        package = themeLib.fonts.emoji.package pkgs;
        name = themeLib.fonts.emoji.name;
      };
    };
  };

  # Qt theming: Stylix's qt target (auto-enabled) owns it — the GNOME-era
  # adwaita-qt hand-roll died with home/gnome.nix in the Phase 3 rip-out.

  home-manager.sharedModules = [
    # Stylix's hm icons target only sets gtk.iconTheme (settings.ini), but
    # GTK apps (Nautilus, Loupe, Calculator) read the icon theme from
    # gsettings via the gtk portal's Settings iface — set the dconf key so
    # they actually pick the theme up. dconf itself: programs.dconf.enable
    # in default.nix (GNOME used to provide it implicitly).
    {
      dconf.settings."org/gnome/desktop/interface".icon-theme = "ClaudeOS";
    }
  ];
}
