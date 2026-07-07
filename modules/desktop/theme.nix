{
  config,
  lib,
  pkgs,
  ...
}:

let
  themeLib = import ../../lib/theme.nix;

  # GNOME Shell accent colors: Stylix rebuilds the shell theme gresource with
  # our palette, but the upstream SCSS emits `-st-accent-color` /
  # `-st-accent-fg-color` as *runtime* tokens that St resolves from the
  # org.gnome.desktop.interface accent-color enum (9 fixed presets, default
  # blue — none terracotta). Rewriting the tokens in the compiled CSS bakes
  # the palette in for the session, lock screen, and GDM alike.
  #
  # `-st-accent-color` is the accent background (quick-settings toggles,
  # checked buttons, calendar today, focus highlights); `-st-accent-fg-color`
  # is the text/icon color drawn ON that background. Brand-faithful picks:
  # terracotta + white-on-terracotta, matching claude.ai's own buttons
  # (--accent-brand / --oncolor-100).
  shellAccentSubstitutions = {
    "-st-accent-color" = config.lib.stylix.colors.withHashtag.base0D;
    "-st-accent-fg-color" = config.lib.stylix.colors.withHashtag.base07;
  };

  shellAccentSedArgs = lib.concatStringsSep " " (
    lib.mapAttrsToList (token: color: "-e 's/${token}/${color}/g'") shellAccentSubstitutions
  );

  # Stylix's home-manager gnome target ALSO themes the shell: it installs the
  # User Themes extension and loads its own compiled CSS as a user theme,
  # which cascades over the default stylesheet — with the runtime accent
  # tokens still in it. Replace that file with the dark stylesheet from our
  # patched gresource (pkgs.gnome-shell here is the overlay result, thanks to
  # home-manager.useGlobalPkgs), so session and GDM share one stylesheet.
  shellUserThemeCss =
    pkgs.runCommand "claudeos-shell-user-theme.css"
      {
        nativeBuildInputs = [ pkgs.glib.dev ];
      }
      ''
        gresource extract ${pkgs.gnome-shell}/share/gnome-shell/gnome-shell-theme.gresource \
          /org/gnome/shell/theme/gnome-shell-dark.css > $out
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

    # Chicago skyline wallpaper
    image = ../../assets/chicago.jpg;
    imageScalingMode = "fill";

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

  # Qt applications should use GTK theme for consistency
  qt = {
    enable = true;
    platformTheme = lib.mkForce "gtk2";
    style = lib.mkForce "adwaita-dark";
  };

  # Stylix's home-manager qt target detects GNOME and sets the deprecated
  # platformTheme "gnome", which Stylix itself flags as unsupported — Qt
  # theming is handled entirely by the system-level qt block above
  home-manager.sharedModules = [
    { stylix.targets.qt.enable = false; }

    # Override the shell CSS Stylix's gnome target installs for the User
    # Themes extension (see shellUserThemeCss above).
    {
      xdg.dataFile."themes/Stylix/gnome-shell/gnome-shell.css".source = lib.mkForce shellUserThemeCss;
    }
  ];

  # XDG portals are provided and configured by GNOME itself
  # (xdg-desktop-portal-gnome + gtk fallback) — no manual wiring needed

  # Rewrite runtime accent tokens in the shell stylesheet (see
  # shellAccentSubstitutions above). mkAfter orders this overlay after
  # Stylix's own gnome-shell overlay, so we post-process the gresource
  # Stylix already themed rather than the vanilla Adwaita one.
  nixpkgs.overlays = lib.mkAfter [
    (final: prev: {
      gnome-shell = prev.gnome-shell.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.glib.dev ];
        postFixup = (old.postFixup or "") + ''
          gresource=$out/share/gnome-shell/gnome-shell-theme.gresource
          workdir=$(mktemp -d)
          mkdir -p "$workdir/theme"
          for resource in $(gresource list "$gresource"); do
            gresource extract "$gresource" "$resource" > "$workdir/theme/''${resource##*/}"
          done
          sed -i ${shellAccentSedArgs} "$workdir/theme/"*.css
          {
            echo '<?xml version="1.0" encoding="UTF-8"?>'
            echo '<gresources><gresource prefix="/org/gnome/shell/theme">'
            for file in "$workdir/theme"/*; do
              echo "  <file>''${file##*/}</file>"
            done
            echo '</gresource></gresources>'
          } > "$workdir/theme.gresource.xml"
          glib-compile-resources --sourcedir="$workdir/theme" \
            --target="$gresource" "$workdir/theme.gresource.xml"
        '';
      });
    })
  ];
}
