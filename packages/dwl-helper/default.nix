{
  lib,
  rustPlatform,
  pkg-config,
  libpulseaudio,
}:

rustPlatform.buildRustPackage {
  pname = "dwl-helper";
  version = "0.1.0";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./Cargo.toml
      ./Cargo.lock
      ./src
      ./protocols
      ./tests
    ];
  };
  cargoLock.lockFile = ./Cargo.lock;
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ libpulseaudio ];
  meta = {
    description = "Event-driven audio and workspace bridge for the DWL desktop";
    mainProgram = "dwl-helper";
    platforms = lib.platforms.linux;
  };
}
