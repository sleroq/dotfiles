{
  lib,
  beam_minimal,
  fetchFromGitHub,
}:
let
  beam = beam_minimal.packages.erlang_29.overrideScope (
    final: _prev: {
      elixir = final.elixir_1_20;
    }
  );
in
beam.mixRelease (finalAttrs: {
  pname = "paseo-relay";
  version = "0.1.0-unstable-2026-10-13";

  src = fetchFromGitHub {
    owner = "getpaseo";
    repo = "paseo-relay";
    rev = "3fc41c96c8c63f3a7109e832899cc57d473c4531";
    hash = "sha256-53r3Mz1GCv5Vozbg02YfiGABn8HTvoao5R+4CxTKj3w=";
  };

  mixFodDeps = beam.fetchMixDeps {
    pname = "paseo-relay-deps";
    inherit (finalAttrs) src version;
    hash = "sha256-3J2C4XGqjdM0TYf+Vkv5/AY59tiKLVX81Gxrs9pvKuY=";
  };

  meta = {
    description = "WebSocket relay for Paseo";
    homepage = "https://github.com/getpaseo/paseo-relay";
    license = lib.licenses.asl20;
    mainProgram = "paseo_relay";
    platforms = lib.platforms.linux;
  };
})
