{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  zlib,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "rift";
  version = "0.0.13";

  src =
    let
      releases = {
        x86_64-linux = {
          target = "x86_64-unknown-linux-gnu";
          hash = "sha256-Q6cBY5dCZiDAqX7meKPgJ6H0uD+4g3fMaxcJBHSr8F8=";
        };
        aarch64-darwin = {
          target = "aarch64-apple-darwin";
          hash = "sha256-Tl9ti1yNjQ2RSCsITQVYfNMMLmuJpIxry5vr+FKp2Fo=";
        };
        x86_64-darwin = {
          target = "x86_64-apple-darwin";
          hash = "sha256-Zk2FehrIqxsUScloyC6tFqP0lKZwq7ddSsjZE4vHdTg=";
        };
      };
      release = releases.${stdenv.hostPlatform.system};
    in
    fetchurl {
      url = "https://github.com/anomalyco/rift/releases/download/v${finalAttrs.version}/rift-v${finalAttrs.version}-${release.target}.tar.gz";
      inherit (release) hash;
    };

  sourceRoot = ".";
  dontBuild = true;
  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
    zlib
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 rift $out/bin/rift
    runHook postInstall
  '';

  meta = {
    description = "Instant copy-on-write workspaces for coding agents and parallel work";
    homepage = "https://github.com/anomalyco/rift";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "rift";
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];
  };
})
