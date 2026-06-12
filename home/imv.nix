{ config, ... }:

let
  # Stylix base16 palette — imv wants bare rrggbb values (no leading #)
  c = config.lib.stylix.colors;
in
{
  programs.imv = {
    enable = true;

    settings = {
      options = {
        # Background color — use a dark neutral to match theme
        background = c.base00;

        # Start in fullscreen for tiling WM (window fills tile anyway)
        fullscreen = false;

        # Overlay info text (toggle with 'd')
        overlay = false;
        overlay_font = "JetBrainsMono Nerd Font:11";
        overlay_text = "$imv_current_file [$imv_current_index/$imv_file_count] $(imv_width)x$(imv_height) $imv_scale";
        overlay_position_bottom = true;
        overlay_background_color = c.base01;
        overlay_text_color = c.base05;

        # Scaling
        scaling_mode = "shrink"; # Don't upscale small images
        upscaling_method = "linear";

        # Suppress default binds so we start clean
        suppress_default_binds = true;
      };

      # Colemak-friendly keybindings — mnemonic and arrow-based
      binds = {
        # Navigation between images
        "<Left>" = "prev";
        "<Right>" = "next";
        "<Shift+Left>" = "goto 0"; # First image
        "<Shift+Right>" = "goto -1"; # Last image

        # Panning (when zoomed in)
        "<Up>" = "pan 0 50";
        "<Down>" = "pan 0 -50";

        # Zoom
        "=" = "zoom 1";
        "-" = "zoom -1";
        "0" = "scaling shrink"; # Reset to fit

        # Actions
        "f" = "fullscreen"; # (f)ullscreen
        "d" = "overlay"; # (d)etails overlay
        "r" = "rotate_by 90"; # (r)otate

        # Center and reset
        "c" = "center"; # (c)enter

        # Close / quit
        "q" = "quit";

        # Clipboard — copy current file path
        "y" = "exec wl-copy < $imv_current_file"; # (y)ank to clipboard

        # Open in external editor (if needed)
        "o" = "exec xdg-open $imv_current_file"; # (o)pen externally

        # Delete (move to trash, with confirmation via script)
        # Intentionally not bound — too dangerous for a single keypress
      };
    };
  };
}
