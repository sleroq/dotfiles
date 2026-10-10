{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchzip,
  cmake,
  pkg-config,
  obs-studio,
  ffmpeg,
  qt6,
}:

let
  version = "0.6.12";
  libmoq = fetchzip {
    url = "https://github.com/moq-dev/moq/releases/download/libmoq-v${version}/moq-${version}-x86_64-unknown-linux-gnu.tar.gz";
    hash = "sha256-mGbIzpWs5k151RE6IALB8gzp+9xqO+ghshEcg/zTAH8=";
  };
in
stdenv.mkDerivation {
  pname = "obs-moq";
  inherit version;

  src = fetchFromGitHub {
    owner = "moq-dev";
    repo = "moq";
    rev = "libmoq-v${version}";
    hash = "sha256-wXpBwI63AOz/O2NhkSnOBOlXYSeSurDhar5JOb0HbXA=";
  };

  sourceRoot = "source/cpp/obs";

  nativeBuildInputs = [
    cmake
    pkg-config
  ];
  buildInputs = [
    obs-studio
    ffmpeg
    qt6.qtbase
  ];

  dontWrapQtApps = true;

  cmakeFlags = [
    "-DMOQ_LOCAL="
    "-DMOQ_VERSION=${version}"
    "-DFETCHCONTENT_SOURCE_DIR_MOQ=${libmoq}"
    "-DPLUGIN_VERSION_OVERRIDE=${version}"
    "-DENABLE_FRONTEND_API=ON"
    "-DENABLE_QT=ON"
    "-DBUILD_PLUGIN=ON"
  ];

  meta = {
    description = "Media over QUIC output, stream service, and source for OBS Studio";
    homepage = "https://github.com/moq-dev/moq";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
  };
}
