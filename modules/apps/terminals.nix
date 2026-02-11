{ ... }:

{
  # Ghostty is installed via home-manager in home/ghostty.nix
  # No system-level installation needed (avoids duplicate launcher entries)

  # Set Ghostty as default terminal
  environment.sessionVariables = {
    TERMINAL = "ghostty";
  };

  # Ghostty .desktop file comes from home-manager; no custom one needed
  # The home-manager com.mitchellh.ghostty.desktop already handles launcher entry
}
