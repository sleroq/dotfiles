{ stdenv
, lib
, fetchurl
, libxkbcommon
, systemd
, xorg
, electron_13
, makeWrapper
, makeDesktopItem
}:
let
  desktopItem = makeDesktopItem rec {
    name = "Obinskit";
    exec = "obinskit";
    icon = "obinskit";
    desktopName = "Obinskit";
    genericName = "Obinskit keyboard configurator";
    categories = [ "Utility" ];
  };
  electron = electron_13;
in
stdenv.mkDerivation rec {
  pname = "obinskit";
  version = "1.2.11";

  src = fetchurl {
    url = "https://annepro.s3.amazonaws.com/4-tar-gz.tar";
    sha256 = "sha256-4jL9/0zvKEe0IbAcSQXuqoYGVX6VCAgI/NaQisN26RM=";
  };

  unpackPhase = "tar -xf $src";

  sourceRoot = "ObinsKit_${version}_x64";

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/opt/obinskit

    cp -r resources $out/opt/obinskit/
    cp -r locales $out/opt/obinskit/

    mkdir -p $out/share/{applications,pixmaps}
    install resources/icons/tray-darwin@2x.png $out/share/pixmaps/obinskit.png
    ln -s ${desktopItem}/share/applications/* $out/share/applications
  '';

  postFixup = ''
    makeWrapper ${electron}/bin/electron $out/bin/${pname} \
      --add-flags $out/opt/obinskit/resources/app.asar \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ stdenv.cc.cc.lib libxkbcommon (lib.getLib systemd) xorg.libXt xorg.libXtst ]}"
  '';

  meta = with lib; {
    description = "Graphical configurator for Anne Pro and Anne Pro II keyboards";
    homepage = "https://www.hexcore.xyz/obinskit";
    license = licenses.unfree;
    maintainers = with maintainers; [ shou ];
    platforms = [ "x86_64-linux" ];
  };
}
