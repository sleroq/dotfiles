{
  lib,
  fetchFromGitHub,
  buildGoModule,
}:
buildGoModule {
  pname = "broadcast-box";
  version = "chat";

  src = fetchFromGitHub {
    owner = "sleroq";
    repo = "broadcast-box";
    rev = "0b3ed04a284e735f4e95ad5a25f95295d77278f2";
    hash = "sha256-i8mcG+w4xueJ4+/qHva8Dz9oDu3Igo7hyrHgJX9pwYg=";
  };

  vendorHash = "sha256-3/ZuNHU1MJD5ew7abWU81EF/G2fJ6eQLslSEnv7m+Xg=";
  proxyVendor = true;

  doCheck = false;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share
    touch $out/share/index.html
    install -Dm755 $GOPATH/bin/broadcast-box -t $out/bin
    runHook postInstall
  '';

  meta = with lib; {
    description = "WebRTC broadcast server (chat branch)";
    homepage = "https://github.com/sleroq/broadcast-box";
    license = licenses.mit;
    mainProgram = "broadcast-box";
  };
}
