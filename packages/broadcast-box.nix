{
  lib,
  fetchFromGitHub,
  buildGoModule,
  buildNpmPackage,
  version ? "unstable-2026-07-30",
  owner ? "Glimesh",
  repo ? "broadcast-box",
  rev ? "4767e4ab1ab25c7de3edf41ea1452222b9c57d19",
  hash ? "sha256-3nNfesVVNTP/0YGWKSYEyNxY2Qo0pyv6Qdi6eIcy5QE=",
  vendorHash ? "sha256-NQoDxuuYsIvUGf2W+bShEhgCrWrliz45c8+v48tHKp0=",
  frontendLock ? null,
  frontendNpmDepsHash ? "sha256-lvW8iyfGprhaegWEXqfwYzPKeieVJ/6O/ka9H5R5a0Y=",
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
