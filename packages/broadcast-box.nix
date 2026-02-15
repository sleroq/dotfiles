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
    rev = "7ad558ad2cbdd781e59da24744f76acc13f98988";
    hash = "sha256-ffREwNUH2UMBh/q7e4c2Q6EhxmlnPciqjSIxlDnjxE8=";
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
