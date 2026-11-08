{
  lib,
  fetchFromGitHub,
  buildGoModule,
  buildNpmPackage,
  version ? "unstable-2026-11-07",
  owner ? "Glimesh",
  repo ? "broadcast-box",
  rev ? "259aaa19c3cce13f3f93e638181029105d3ea7ed",
  hash ? "sha256-vELwoBxs/rFiCpayMgwhtIjUsbRIXzVLeDyEjducvOo=",
  vendorHash ? "sha256-0LyylgNtAD/HT/ojhyI2eo5e8G4+4BU1jO4zXkohAIs=",
  frontendLock ? null,
  frontendNpmDepsHash ? "sha256-eDbq/jhbPq98TmfYuh6rBid+HG7NxkPVufWC7YFtcKo=",
}:
let
  src = fetchFromGitHub {
    inherit
      owner
      repo
      rev
      hash
      ;
  };

  frontend = buildNpmPackage {
    pname = "broadcast-box-web";
    inherit version src;
    sourceRoot = "source/web";
    npmDepsHash = frontendNpmDepsHash;

    postPatch = lib.optionalString (frontendLock != null) ''
      cp ${frontendLock} package-lock.json
    '';

    installPhase = ''
      runHook preInstall
      cp -r build $out
      runHook postInstall
    '';
  };
in
buildGoModule {
  pname = "broadcast-box";
  inherit version;

  inherit src;

  inherit vendorHash;
  proxyVendor = true;

  doCheck = false;

  installPhase = ''
    runHook preInstall
    install -Dm755 $GOPATH/bin/broadcast-box -t $out/bin
    install -Dm644 .env.production -t $out/bin
    mkdir -p $out/share
    cp -r ${frontend} $out/share/web
    runHook postInstall
  '';

  meta = with lib; {
    description = "WebRTC broadcast server";
    homepage = "https://github.com/${owner}/${repo}";
    license = licenses.mit;
    mainProgram = "broadcast-box";
  };
}
