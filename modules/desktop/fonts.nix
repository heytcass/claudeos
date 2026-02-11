{ pkgs, ... }:

{
  # Font configuration
  fonts = {
    # Enable font configuration management
    fontconfig = {
      enable = true;
      defaultFonts = {
        # Mirroring Claude AI's typography choices
        # Claude uses Inter for its interface - clean, modern, highly readable
        sansSerif = [ "Inter" "Noto Sans" "DejaVu Sans" ];
        serif = [ "Noto Serif" "DejaVu Serif" ];
        monospace = [ "JetBrains Mono" "Symbols Nerd Font" "Fira Code" "DejaVu Sans Mono" ];
        emoji = [ "Noto Color Emoji" ]; # Package: noto-fonts-color-emoji
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
      # Primary UI font - matches Claude AI interface
      inter # Claude's main interface font

      # System fonts for fallbacks and Unicode coverage
      noto-fonts # Excellent Unicode coverage
      noto-fonts-cjk-sans # Chinese, Japanese, Korean
      noto-fonts-color-emoji # Emoji support
      liberation_ttf # Microsoft font replacements
      dejavu_fonts # Bitstream Vera successor

      # Programming fonts with ligatures and Nerd Font icons
      # Note: nerdfonts was split into individual packages in nixpkgs
      nerd-fonts.jetbrains-mono # Primary coding font with icons
      nerd-fonts.fira-code # Alternative with ligatures and icons
      nerd-fonts.symbols-only # Standalone symbol fallback for UI glyphs

      # Non-Nerd Font versions (for compatibility)
      fira-code # Mozilla's programming font
      jetbrains-mono # JetBrains monospace
    ];

    # Enable support for additional font formats
    enableDefaultPackages = true;

    # Ensure Symbols Nerd Font is tried before Noto Color Emoji for monospace.
    # Without this, fontconfig may resolve shared codepoints (e.g. U+23F8 ⏸)
    # to the color emoji font, producing oversized glyphs in terminals.
    fontconfig.localConf = ''
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
      <fontconfig>
        <alias>
          <family>monospace</family>
          <prefer>
            <family>Symbols Nerd Font</family>
          </prefer>
        </alias>
      </fontconfig>
    '';
  };
}
