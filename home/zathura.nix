{ ... }:

{
  programs.zathura = {
    enable = true;

    # Colors are managed by Stylix — see modules/desktop/theme.nix

    options = {
      # Use clipboard (not primary selection)
      selection-clipboard = "clipboard";

      # Recolor documents to match theme by default
      recolor = true;

      # Status bar
      guioptions = "s"; # Show statusbar only (no inputbar until activated)

      # Incremental search
      incremental-search = true;

      # Window title
      window-title-basename = true;

      # Scroll behavior
      scroll-step = 80;
      scroll-page-aware = true;

      # Padding
      statusbar-h-padding = 8;
      statusbar-v-padding = 4;
      page-padding = 4;
    };

    # Colemak-friendly keybindings — mnemonic shortcuts, not vim positional
    mappings = {
      # Navigation — arrow keys are natural on any layout
      "<Left>" = "scroll left";
      "<Right>" = "scroll right";
      "<Up>" = "scroll up";
      "<Down>" = "scroll down";

      # Page navigation
      "<Space>" = "scroll full-down";
      "<S-Space>" = "scroll full-up";
      "<C-d>" = "scroll half-down";
      "<C-u>" = "scroll half-up";

      # Zoom — mnemonic: +/- and = for reset
      "=" = "zoom in";
      "-" = "zoom out";
      "0" = "zoom reset"; # Fit to window

      # Fit modes
      "w" = "adjust_window width"; # (w)idth
      "b" = "adjust_window best-fit"; # (b)est fit

      # Page jumping
      "<Home>" = "goto 1"; # First page
      "<End>" = "goto -1"; # Last page

      # Search — / is universal
      "/" = "search forward";
      "?" = "search backward";
      "n" = "search forward"; # (n)ext match
      "N" = "search backward"; # Previous match

      # Actions
      "r" = "rotate"; # (r)otate
      "p" = "print"; # (p)rint
      "i" = "recolor"; # (i)nvert / recolor toggle
      "d" = "toggle_page_mode"; # (d)ual page toggle
      "f" = "toggle_fullscreen"; # (f)ullscreen
      "t" = "toggle_index"; # (t)able of contents

      # Reload
      "<C-r>" = "reload";

      # Quit
      "q" = "quit";
    };
  };
}
