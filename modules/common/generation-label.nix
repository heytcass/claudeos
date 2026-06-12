# modules/common/generation-label.nix — Claude-named generations.
#
# The repo-root `generation-label` file holds a short slug describing the
# pending change (written by the fish `rebuild` function and the auto-update
# service, usually authored by haiku from the diff). It lands in
# system.nixos.tags, so the systemd-boot menu and
# `nixos-rebuild list-generations` read like a changelog instead of
# "Generation 213". Charset is enforced here because system.nixos.label
# rejects anything outside [a-zA-Z0-9:_.-] at eval time.
{ lib, ... }:

let
  raw = lib.fileContents ../../generation-label;
  slug = builtins.replaceStrings [ " " ] [ "-" ] raw;
  sanitized = lib.concatStrings (
    builtins.filter (c: builtins.match "[a-zA-Z0-9:_.-]" c != null) (lib.stringToCharacters slug)
  );
in
{
  system.nixos.tags = lib.optional (sanitized != "") sanitized;
}
