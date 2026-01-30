{
  lib,
  fetchFromGitHub,
  buildGoModule,
}:
buildGoModule {
  pname = "broadcast-box";
  version = "chat-98aba8d";

  src = fetchFromGitHub {
    owner = "sleroq";
    repo = "broadcast-box";
    rev = "c9210a0aa31709fef7e5621999a6e98a93bcfb87";
    hash = "sha256-HuuS6sUX6YJ18p5cjXAHcY4/bGfVoxMCIZQpEmwnVxs=";
  };

  vendorHash = "sha256-7tgx6cJf2+xBod89k6sg0FfZseKoErwipHqsvPoTaB0=";
  proxyVendor = true;

  # Add NixOS environment support (equivalent to allow-no-env.patch)
  # and point to the share directory for the (empty) frontend
  postPatch = ''
    substituteInPlace main.go \
      --replace-fail 'if os.Getenv("APP_ENV") == "development" {' 'if os.Getenv("APP_ENV") == "nixos" { return nil } else if os.Getenv("APP_ENV") == "development" {' \
      --replace-fail './web/build' "${placeholder "out"}/share"
  '';

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
