# lib/action-id.nix — the stable id of a registry action (lib/keybindings.nix):
# a slug of its `name` ("Circle to ask" → "circle-to-ask"). The usage counter
# (modules/apps/usage.nix) reports by it, and home/hyprland.nix stamps it on the
# key binds and on Keybinds.actions for the summon to log — one function, so
# logger and report cannot disagree. Renaming an action starts a new id; its
# old log lines then show in the report as "not in the registry".
{ lib }:
name:
lib.concatStringsSep "-" (
  lib.filter (s: builtins.isString s && s != "") (builtins.split "[^a-z0-9]+" (lib.toLower name))
)
