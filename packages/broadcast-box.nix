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
    rev = "09a9e6b70a9c027ddf71b5197c8ad7d02ad146d3";
    hash = "sha256-LOSwDLbT+njqnQJLQMrssHtPLUQJfrA7REstAsU0n40=";
  };

  vendorHash = "sha256-Cf/CEKs7/HcLHh/D8H4alLyq8ZWh/SD+oVb9la6uR2w=";
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
