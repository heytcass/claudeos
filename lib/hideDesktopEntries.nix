# Generate a derivation that hides .desktop entries from the application launcher.
# Usage: hideDesktopEntries = import ./hideDesktopEntries.nix { inherit pkgs lib; };
#        hideDesktopEntries [ "app-name" "another-app" ]
{ pkgs, lib }:
names:
lib.hiPrio (pkgs.runCommand "desktop-hide-${builtins.hashString "md5" (toString names)}" { } ''
  mkdir -p $out/share/applications
  ${lib.concatMapStringsSep "\n" (name: ''
    printf '[Desktop Entry]\nNoDisplay=true\n' > "$out/share/applications/${name}.desktop"
  '') names}
'')
