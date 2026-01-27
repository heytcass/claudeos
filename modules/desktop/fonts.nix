{ config, lib, pkgs, ... }:

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
        monospace = [ "JetBrains Mono" "Fira Code" "DejaVu Sans Mono" ];
        emoji = [ "Noto Color Emoji" ];
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
      inter                        # Claude's main interface font

      # System fonts for fallbacks and Unicode coverage
      noto-fonts                   # Excellent Unicode coverage
      noto-fonts-cjk-sans         # Chinese, Japanese, Korean
      noto-fonts-emoji            # Emoji support
      liberation_ttf              # Microsoft font replacements
      dejavu_fonts                # Bitstream Vera successor

      # Programming fonts with ligatures
      (nerdfonts.override {        # Patched fonts with icons for terminals
        fonts = [
          "JetBrainsMono"          # Primary coding font
          "FiraCode"               # Alternative with ligatures
        ];
      })

      # Additional fonts
      fira-code                    # Mozilla's programming font (non-Nerd Font)
      jetbrains-mono               # JetBrains monospace (non-Nerd Font)
    ];

    # Enable support for additional font formats
    enableDefaultPackages = true;
  };
}
