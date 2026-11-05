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
  version = "0.1.0-unstable-2026-10-28";

  src = fetchFromGitHub {
    owner = "getpaseo";
    repo = "paseo-relay";
    rev = "5f4b7636af41a85ef20200c0b7e99dd1ea2ee1f2";
    hash = "sha256-F4PQg5vU9sI3d9XWukbINdBmhbfcehBzeUVxPKZ06Jg=";
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
