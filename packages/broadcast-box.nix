{
  lib,
  fetchFromGitHub,
  buildGoModule,
  buildNpmPackage,
  version ? "unstable-2026-07-29",
  owner ? "Glimesh",
  rev ? "03dcbfa724fba2b6b577c644dd0c3d76422269ac",
  hash ? "sha256-AXW2xu3N+Uevg/Gc/ZI3UUnvgt4wcJkiY6MZDGdx6AY=",
  vendorHash ? "sha256-NQoDxuuYsIvUGf2W+bShEhgCrWrliz45c8+v48tHKp0=",
  frontendLock ? null,
  frontendNpmDepsHash ? "sha256-lvW8iyfGprhaegWEXqfwYzPKeieVJ/6O/ka9H5R5a0Y=",
}:
let
  src = fetchFromGitHub {
    inherit owner rev hash;
    repo = "broadcast-box";
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
    homepage = "https://github.com/${owner}/broadcast-box";
    license = licenses.mit;
    mainProgram = "broadcast-box";
  };
}
