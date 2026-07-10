# Central theme constants — single source of truth for font and icon names
# AND the name→package pairing. Import this file from any module that needs
# theme-related values; each font's `package` is a function of pkgs so this
# file stays importable without arguments (names are plain data).
{
  # Extended palette — colors outside the base16 scheme
  # that are used across modules. Centralised here so they're
  # easy to update without grepping for hex values.
  colors = { };

  fonts = {
    monospace = {
      name = "JetBrains Mono";
      nerdName = "JetBrains Mono Nerd Font";
      package = pkgs: pkgs.nerd-fonts.jetbrains-mono;
    };
    sansSerif = {
      name = "Inter";
      package = pkgs: pkgs.inter;
    };
    # Lora is the Anthropic brand body face. It IS the system serif: document
    # and prose contexts carry the brand, while sansSerif stays Inter, which
    # was drawn for dense UI chrome. (Noto Serif remains available via
    # noto-fonts, kept in fonts.packages for its Noto Sans fallback.)
    serif = {
      name = "Lora";
      package = pkgs: pkgs.lora;
    };
    emoji = {
      name = "Noto Color Emoji";
      package = pkgs: pkgs.noto-fonts-color-emoji;
    };
    symbols = {
      name = "Symbols Nerd Font";
      fallback = "Noto Sans Symbols 2";
      package = pkgs: pkgs.nerd-fonts.symbols-only;
    };
  };
  # Anthropic brand display face. Deliberately NOT in `fonts` above: those keys
  # drive Stylix (GTK, shell, editor), and Poppins is a geometric display face
  # — legible in a headline, poor at 11px UI sizes. Installed for fontconfig so
  # locally-rendered artifacts (the morning desk dashboard) can name it for
  # headings, without it becoming the UI font.
  # The brand body face, Lora, needs no entry here: it IS `fonts.serif`.
  # See .claude/skills/brand-guidelines.
  brand = {
    display = {
      name = "Poppins";
      package = pkgs: pkgs.poppins;
    };
  };

  icons = {
    name = "Adwaita";
  };
}
