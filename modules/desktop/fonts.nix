{ pkgs, ... }:

let
  themeLib = import ../../lib/theme.nix;
in
{
  fonts = {
    # Enable font configuration management
    fontconfig = {
      enable = true;
      defaultFonts = {
        # Mirroring Claude AI's typography choices
        sansSerif = [
          themeLib.fonts.sansSerif.name
          "Noto Sans"
          "DejaVu Sans"
        ];
        serif = [
          themeLib.fonts.serif.name
          "Noto Serif CJK SC"
          "DejaVu Serif"
        ];
        monospace = [
          themeLib.fonts.monospace.nerdName
          themeLib.fonts.symbols.name
          "Fira Code"
          "DejaVu Sans Mono"
        ];
        emoji = [ themeLib.fonts.emoji.name ];
      };

      # Better font rendering
      subpixel.rgba = "rgb";
      hinting = {
        enable = true;
        autohint = false;
        style = "slight";
      };
      antialias = true;
    };

    # Font packages — the themed fonts come from lib/theme.nix (one
    # name→package pairing), plus extra fallback/coverage fonts
    packages =
      map (font: font.package pkgs) (builtins.attrValues themeLib.fonts)
      # Brand faces: installed so generated artifacts can name them, but
      # absent from defaultFonts above — they never become the UI font.
      ++ map (font: font.package pkgs) (builtins.attrValues themeLib.brand)
      ++ (with pkgs; [
        # System fonts for fallbacks and Unicode coverage
        noto-fonts # provides the "Noto Sans" sans fallback named above
        noto-fonts-cjk-sans
        noto-fonts-cjk-serif # CJK in serif contexts rendered as tofu without it
        liberation_ttf
        dejavu_fonts

        # Secondary programming font with ligatures
        nerd-fonts.fira-code
      ]);

    # Enable support for additional font formats
    enableDefaultPackages = true;

    # Ensure Symbols Nerd Font is tried before Noto Color Emoji for monospace
    fontconfig.localConf = ''
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
      <fontconfig>
        <alias>
          <family>monospace</family>
          <prefer>
            <family>${themeLib.fonts.symbols.name}</family>
          </prefer>
        </alias>
      </fontconfig>
    '';
  };
}
