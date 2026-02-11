{ pkgs, ... }:

{
  # Install Chrome browser (remove duplicate .desktop file that causes
  # COSMIC launcher to show two "Google Chrome" entries)
  environment.systemPackages = [
    (pkgs.runCommand "google-chrome-deduped"
      {
        nativeBuildInputs = [ pkgs.makeWrapper ];
        meta = pkgs.google-chrome.meta or { };
      } ''
      mkdir -p $out
      for dir in ${pkgs.google-chrome}/*; do
        ln -s "$dir" "$out/$(basename "$dir")"
      done
      # Replace share with a filtered copy (no com.google.Chrome.desktop)
      rm -f $out/share
      mkdir -p $out/share
      for item in ${pkgs.google-chrome}/share/*; do
        if [ "$(basename "$item")" = "applications" ]; then
          mkdir -p $out/share/applications
          for desktop in ${pkgs.google-chrome}/share/applications/*; do
            if [ "$(basename "$desktop")" != "com.google.Chrome.desktop" ]; then
              ln -s "$desktop" "$out/share/applications/"
            fi
          done
        else
          ln -s "$item" "$out/share/$(basename "$item")"
        fi
      done
    '')
  ];

  # Note: Chrome is unfree, but allowUnfree is already configured
  # in modules/common/nix.nix

  # Chrome extensions and sync must be configured manually
  # (cannot be managed declaratively)
}
