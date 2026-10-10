{
  appimageTools,
  version ? "0.19.2.1",
  hash ? "sha256-oEVQo8fHC9rTrNOkQw7ajSr8C/cXOpxYpAP+q5UXCH8=",
}:

let
  pname = "helium";
  src = builtins.fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/${pname}-${version}-x86_64.AppImage";
    sha256 = hash;
  };
  contents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 rec {
  inherit version pname src;

  extraInstallCommands = ''
    install -m 444 -D ${contents}/${pname}.desktop -t $out/share/applications
    substituteInPlace $out/share/applications/${pname}.desktop \
      --replace 'Exec=AppRun' 'Exec=${pname}'
    cp -r ${contents}/usr/share/icons $out/share
  '';
}
