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
  version = "0.6.10";
  libmoq = fetchzip {
    url = "https://github.com/moq-dev/moq/releases/download/libmoq-v${version}/moq-${version}-x86_64-unknown-linux-gnu.tar.gz";
    hash = "sha256-DBnqBJfnEPmYK+X/7AP77+t8uXl3qSnRe4Da+QbCVWM=";
  };
in
stdenv.mkDerivation {
  pname = "obs-moq";
  inherit version;

  src = fetchFromGitHub {
    owner = "moq-dev";
    repo = "moq";
    # Match the released libmoq; the obs-moq tag expects an unreleased moq-c archive.
    rev = "cd59d15b07c2c2c8a5bfa8a2e82b3bbc24e82a76";
    hash = "sha256-nRrxPmzZLQ+1ZVRhWmnxRvDn11UsmJlYI0Ioq8/urXA=";
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
