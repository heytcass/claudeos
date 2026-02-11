# Central theme constants — single source of truth for font and icon names.
# Import this file from any module that needs theme-related string values.
# Packages are declared in their respective modules; this file is pure data.
{
  fonts = {
    monospace = {
      name = "JetBrains Mono";
      nerdName = "JetBrains Mono Nerd Font";
    };
    sansSerif = {
      name = "Inter";
    };
    serif = {
      name = "Noto Serif";
    };
    emoji = {
      name = "Noto Color Emoji";
    };
    symbols = {
      name = "Symbols Nerd Font";
      fallback = "Noto Sans Symbols 2";
    };
  };
  icons = {
    name = "Adwaita";
  };
}
