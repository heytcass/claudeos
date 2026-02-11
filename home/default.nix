{ pkgs, lib, user, ... }:

{
  # Import all Home Manager modules
  imports = [
    ./shell
    ./ghostty.nix
    ./git.nix
    ./vscode.nix
    ./theme.nix
    ./cosmic.nix
    ./cosmic-theme.nix
  ];

  # This is required for home-manager
  home.stateVersion = "24.11";

  # Basic home configuration
  home.username = user;
  home.homeDirectory = "/home/${user}";

  # Let home-manager manage itself
  programs.home-manager.enable = true;

  # Hide unwanted apps from COSMIC launcher (per-user profile entries)
  # COSMIC doesn't do cross-path XDG deduplication, so overrides must be
  # in the same path. For per-user profile entries, use lib.hiPrio package.
  # System-level hides are in modules/desktop/cosmic-system.nix
  home.packages = [
    (lib.hiPrio (pkgs.runCommand "desktop-hide-user-overrides" { } ''
      mkdir -p $out/share/applications
      for name in \
        yazi \
        code-url-handler \
        kvantummanager \
        qt5ct \
        qt6ct
      do
        cat > "$out/share/applications/$name.desktop" <<EOF
      [Desktop Entry]
      NoDisplay=true
      EOF
      done
    ''))
  ];
}
