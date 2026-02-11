{ ... }:

{
  # Stylix target configuration for Home Manager
  # Controls which applications get themed by Stylix
  stylix = {
    # Enable Stylix targets for specific applications
    targets = {
      gtk.enable = true;
      ghostty.enable = true;
      vscode.enable = true;
    };

    # Optional: Custom GTK CSS overrides
    # Add manual CSS fixes here if Stylix falls short
    targets.gtk.extraCss = ''
      /* Manual CSS overrides can be added here */
    '';
  };

  # Note: Icon theme is Adwaita, configured in home/cosmic.nix
}
