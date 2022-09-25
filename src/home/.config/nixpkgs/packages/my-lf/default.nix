{ lib
, fetchFromGitHub
, stdenv
, file
, openssl
, optionalDeps
}:

stdenv.mkDerivation rec {
  pname = "ctpv";
  version = "1.0";

  src = fetchFromGitHub {
    owner = "NikitaIvanovV";
    repo = "ctpv";
    rev = "972efd368c62974444fa3d6b600aa41cac9db863";
    hash = "sha256-0OuskRCBVm8vMd2zH5u5EPABmCOlEv5N4ZZMdc7bAwM=";
  };

  buildInputs = [ file openssl ];

  makeFlags = [ "PREFIX=$(out)" ];

  preInstall = ''
    make $makeFlags install
  '';

  meta = with lib; {
    description = "Terminal previewer";
    longDescription = ''
      ctpv is a previewer utility for terminals.
      It supports previews for source code, archives, PDF files, images and videos
    '';
    homepage = "https://github.com/NikitaIvanovV/ctpv";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
