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
    serif = {
      name = "Noto Serif";
      package = pkgs: pkgs.noto-fonts;
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
  icons = {
    name = "Adwaita";
  };
}
