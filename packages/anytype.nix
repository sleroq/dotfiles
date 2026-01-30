{
  lib,
  appimageTools,
  makeWrapper,
  version ? "0.46.5",
  hash ? "sha256-AiLuEQhJoyPo1pTmAWvnXMj5pdA/CBO6JvZZVG71W7M=",
}:

let
  pname = "anytype";
  name = "Anytype-${version}";
  src = builtins.fetchurl {
    url = "https://github.com/anyproto/anytype-ts/releases/download/v${version}/${name}.AppImage";
    name = "Anytype-${version}.AppImage";
    sha256 = hash;
  };
  appimageContents = appimageTools.extractType2 { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraPkgs = pkgs: (appimageTools.defaultFhsEnvArgs.multiPkgs pkgs) ++ [ pkgs.libsecret ];

  extraInstallCommands = ''
    # mv $out/bin/${pname} $out/bin/${pname}
    source "${makeWrapper}/nix-support/setup-hook"
    wrapProgram $out/bin/${pname} \
      --add-flags "--ozone-platform=wayland --enable-features=WaylandWindowDecorations"
    install -m 444 -D ${appimageContents}/anytype.desktop -t $out/share/applications
    substituteInPlace $out/share/applications/anytype.desktop \
      --replace 'Exec=AppRun' 'Exec=${pname}'
    for size in 16 32 64 128 256 512 1024; do
      install -m 444 -D ${appimageContents}/usr/share/icons/hicolor/''${size}x''${size}/apps/anytype.png \
        $out/share/icons/hicolor/''${size}x''${size}/apps/anytype.png
    done
  '';

  meta = with lib; {
    description = "P2P note-taking tool";
    homepage = "https://anytype.io/";
    license = licenses.unfree;
    maintainers = with maintainers; [ running-grass ];
    platforms = [ "x86_64-linux" ];
  };
}
