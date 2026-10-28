# sonic-synth — the renderer behind lib/sonic.nix: palette/motion spec (JSON)
# in, earcon WAVs out. See src/main.rs for the voice.
{ lib, rustPlatform }:
rustPlatform.buildRustPackage {
  pname = "sonic-synth";
  version = "0.1.0";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./Cargo.toml
      ./Cargo.lock
      ./src
    ];
  };
  cargoLock.lockFile = ./Cargo.lock;
  meta.mainProgram = "sonic-synth";
}
