{
  lib,
  fetchFromGitHub,
  buildGoModule,
  buildNpmPackage,
  version ? "unstable-2026-11-02",
  owner ? "Glimesh",
  repo ? "broadcast-box",
  rev ? "7645ea15a506a1c059d8a63f4f3db9d2ed25a385",
  hash ? "sha256-Q0M/rXIx/32kezgwrW5ZeFGR0IaO/RyiPq/XgetTOJ4=",
  vendorHash ? "sha256-jCEUvgmOmgwFeRsYfwn/uQiqySgzdmV9pKKImNJbams=",
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
