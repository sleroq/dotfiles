{
  stdenv,
  fetchurl,
  fetchFromGitHub,
  rustPlatform,
  autoPatchelfHook,
  lib,
}:
let
  relay = builtins.fromJSON (builtins.readFile ./moq-relay.json);
  releaseBinary =
    name: version: hash: executable:
    stdenv.mkDerivation {
      pname = name;
      inherit version;
      src = fetchurl {
        url = "https://github.com/moq-dev/moq/releases/download/${name}-v${version}/${name}-v${version}-x86_64-unknown-linux-gnu";
        inherit hash;
      };
      dontUnpack = true;
      dontStrip = true;
      nativeBuildInputs = [ autoPatchelfHook ];
      buildInputs = [ stdenv.cc.cc.lib ];
      installPhase = ''
        runHook preInstall
        install -Dm755 $src $out/bin/${executable}
        runHook postInstall
      '';
      meta = {
        mainProgram = executable;
        platforms = [ "x86_64-linux" ];
        license = with lib.licenses; [
          mit
          asl20
        ];
      };
    };
in
{
  moq-relay = rustPlatform.buildRustPackage rec {
    pname = "moq-relay";
    inherit (relay) version;
    src = fetchFromGitHub {
      owner = "moq-dev";
      repo = "moq";
      rev = "moq-relay-v${version}";
      hash = relay.hash;
    };
    cargoLock.lockFile = "${src}/Cargo.lock";
    cargoBuildFlags = [
      "--package=moq-relay"
      "--features=jemalloc"
    ];
    cargoTestFlags = [
      "--package=moq-stats"
      "no_origin_collects_without_publishing"
    ];
    hardeningDisable = [ "fortify" ];
    RUSTFLAGS = "-C force-frame-pointers=yes";
    patches = [ ./patches/moq-relay-private-stats.patch ];
    meta = {
      mainProgram = "moq-relay";
      platforms = [ "x86_64-linux" ];
      license = with lib.licenses; [
        mit
        asl20
      ];
    };
  };
  moq = releaseBinary "moq-cli" "0.14.10" "sha256-mXzvUvE2fjXMUUutW+91w5IYKX+aHZcWbyaJZTu4sp4=" "moq";
}
