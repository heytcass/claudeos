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
          "DejaVu Serif"
        ];
        monospace = [
          themeLib.fonts.monospace.name
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

    # Font packages
    packages = with pkgs; [
      # Primary UI font — matches Claude AI interface
      inter

      # System fonts for fallbacks and Unicode coverage
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      liberation_ttf
      dejavu_fonts

      # Programming fonts with ligatures and Nerd Font icons
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
      nerd-fonts.symbols-only
    ];

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
