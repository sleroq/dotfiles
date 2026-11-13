{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  zlib,
}:

let
  releaseInfo = builtins.fromJSON (builtins.readFile ./rift.json);
in
stdenv.mkDerivation (finalAttrs: {
  pname = "rift";
  version = releaseInfo.version;

  src =
    let
      releases = {
        x86_64-linux = {
          target = "x86_64-unknown-linux-gnu";
          hash = releaseInfo.hashes."x86_64-unknown-linux-gnu";
        };
        aarch64-darwin = {
          target = "aarch64-apple-darwin";
          hash = releaseInfo.hashes."aarch64-apple-darwin";
        };
        x86_64-darwin = {
          target = "x86_64-apple-darwin";
          hash = releaseInfo.hashes."x86_64-apple-darwin";
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
