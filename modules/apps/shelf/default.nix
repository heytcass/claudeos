# modules/apps/shelf/default.nix — `claudeos-shelf`: the working-memory Shelf
# (docs/plans/2026-10-28-working-memory-shelf.md). A shelf holds the MATERIAL
# of a task context (files by reference; images, text clips and links by
# value) where a context manifest holds its tools and places. Shelves live in
# the context store's own local git repo, so every write — including Claude's
# tidy, later — is a commit that can be reverted.
#
# This CLI is the only writer: the bar's drop target, the capture hotkeys and
# tidy all go through it, and every write is validated against
# ./shelf.schema.json before it lands. The script body lives in
# ./claudeos-shelf.sh (plain bash, no Nix escaping) and runs on the shared
# mkClaudeScriptBin preamble for the context-repo helpers.
{ lib, pkgs, ... }:
let
  claudeLib = import ../../../lib/claude-script.nix { inherit pkgs lib; };
in
{
  environment.systemPackages = [
    (claudeLib.mkClaudeScriptBin {
      name = "claudeos-shelf";
      # check-jsonschema validates writes; xdg-utils opens files/links;
      # wl-clipboard copies text/images; attr reads the download-origin xattr;
      # util-linux provides flock. hyprctl comes from the live session PATH
      # (guarded), as in claudeos-context.
      runtimeInputs = [
        pkgs.check-jsonschema
        pkgs.xdg-utils
        pkgs.wl-clipboard
        pkgs.attr
        pkgs.util-linux
      ];
      text = ''
        SHELF_SCHEMA="${./shelf.schema.json}"
      ''
      + builtins.readFile ./claudeos-shelf.sh;
    })

    # Capture hotkeys (lib/keybindings.nix: Super+S, Super+Shift+S). Both are
    # thin front ends that pick a kind and call claudeos-shelf from PATH, so
    # validation and refusals stay in one place. Success is a low-urgency
    # notification, which also sounds Sonic's notif-low earcon.
    (claudeLib.mkClaudeScriptBin {
      name = "claudeos-shelve-clipboard";
      runtimeInputs = [ pkgs.wl-clipboard ];
      text = builtins.readFile ./shelve-clipboard.sh;
    })
    (claudeLib.mkClaudeScriptBin {
      name = "claudeos-shelve-region";
      runtimeInputs = [
        pkgs.grim
        pkgs.slurp
      ];
      text = builtins.readFile ./shelve-region.sh;
    })
  ];
}
