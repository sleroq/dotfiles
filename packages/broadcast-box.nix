{
  lib,
  fetchFromGitHub,
  buildGoModule,
  buildNpmPackage,
  version ? "unstable-2026-10-21",
  owner ? "Glimesh",
  repo ? "broadcast-box",
  rev ? "d37c9bbfb115562f80d94c5e867f3a4055febb4d",
  hash ? "sha256-EKaQfcim4q/+GHvY4dhuh/gZfiZaUAcMYRAu8U6LiBQ=",
  vendorHash ? "sha256-lgm6xrcBX4gxEfYasmeFbO/nVTcV0r4WPObw1wt8Ahg=",
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
