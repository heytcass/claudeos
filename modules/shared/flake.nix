# ClaudeOS shared baseline — consumed as `github:<owner>/claudeos?dir=modules/shared`.
#
# Deliberately inputless: a consumer's lock gains this one node and nothing
# else, so none of claudeos's desktop inputs ride into its closure. Modules get
# `pkgs`/`lib` from the consumer's own nixpkgs, like any NixOS module.
# The contract every file here must keep is in ./README.md.
{
  description = "ClaudeOS shared baseline: host-agnostic NixOS modules";

  outputs = _: {
    nixosModules.default = ./default.nix;
  };
}
