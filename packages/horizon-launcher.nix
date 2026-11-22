{
  lib,
  appimageTools,
  fetchurl,
  makeWrapper,
}:

let
  pname = "horizon-launcher";
  version = "0.2.98";
  src = fetchurl {
    url = "https://github.com/horizon-rust/horizon/releases/download/launcher%40${version}/horizon-launcher-linux-x86_64.AppImage";
    hash = "sha256-IyQpwmlk3sF87DFXU/dK1v9gUvheChphuYbqYK1zTRA=";
  };
  contents = appimageTools.extract { inherit pname version src; };
in
# Keep the launcher and the upstream game binaries it downloads in the same FHS environment.
appimageTools.wrapType2 {
  inherit pname version src;
  nativeBuildInputs = [ makeWrapper ];
  # Horizon rejects the host /tmp owner as unmapped inside Bubblewrap.
  privateTmp = true;

  extraInstallCommands = ''
    install -Dm644 ${contents}/horizon-launcher.desktop -t "$out/share/applications"
    cp -r ${contents}/usr/share/icons "$out/share/"
    wrapProgram "$out/bin/horizon-launcher" \
      --set HORIZON_LAUNCHER_NO_SELF_UPDATE 1 \
      --set HORIZON_LAUNCHER_DESKTOP_EXEC "$out/bin/horizon-launcher"
  '';

  meta = {
    description = "Launcher for Horizon, a Rust client for Minecraft: Java Edition";
    homepage = "https://playhorizon.dev/";
    license = lib.licenses.lgpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
}
