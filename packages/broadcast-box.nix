{
  lib,
  fetchFromGitHub,
  buildGoModule,
  buildNpmPackage,
  version ? "unstable-2026-09-13",
  owner ? "Glimesh",
  repo ? "broadcast-box",
  rev ? "eacabc0737d5fba61f57999462df5906cec0a5e3",
  hash ? "sha256-97TOeEJlWlXrWK3IQ1s9Uylcx+D/E50DsHx0mPM1TDs=",
  vendorHash ? "sha256-YHFPZuZlgPrYo072pBU47vfGKwjr62YPCT5S3gAjhuI=",
  frontendLock ? null,
  frontendNpmDepsHash ? "sha256-wIEsiJI9SVwMEIAOW5Mubg8yyPXlwTEKNQGmSvey4MY=",
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
