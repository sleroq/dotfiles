{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "sing-box-subscribe-cli";
  version = "1.0.4";

  src = fetchFromGitHub {
    owner = "rainbend";
    repo = "sing-box-subscribe-cli";
    rev = "v${version}";
    hash = "sha256-wHDzB3OPs+yMnyG0Br+dczfOnewBEgxuwlEjCR9vWtg=";
  };

  vendorHash = "sha256-komX1AmHt2NoF1x6xsNa2RFkfVzOXfYEMPhT0zwMxjw=";

  ldflags = [ "-X main.version=v${version}" ];

  meta = {
    description = "Generate sing-box configurations from subscriptions";
    homepage = "https://github.com/rainbend/sing-box-subscribe-cli";
    license = lib.licenses.asl20;
    mainProgram = "sing-box-sub";
  };
}
