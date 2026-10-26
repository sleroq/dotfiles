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
  version = "0.6.18";
  libmoq = fetchzip {
    url = "https://github.com/moq-dev/moq/releases/download/libmoq-v${version}/moq-${version}-x86_64-unknown-linux-gnu.tar.gz";
    hash = "sha256-kFMzOImZa4NOA3SwhncIZ6ZLpuIwF9h1YRh7Hyb/U08=";
  };
in
stdenv.mkDerivation {
  pname = "obs-moq";
  inherit version;

  src = fetchFromGitHub {
    owner = "moq-dev";
    repo = "moq";
    rev = "libmoq-v${version}";
    hash = "sha256-P19alUKzHrlayH988/94cL7WGdpJM2iOWcU93LfUW/I=";
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
