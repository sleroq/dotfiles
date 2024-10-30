{ lib, stdenv
, libXScrnSaver
, makeWrapper
, fetchurl
, wrapGAppsHook
, glib
, gtk3
, unzip
, atomEnv
, libuuid
, at-spi2-atk
, at-spi2-core
, libdrm
, mesa
, libxkbcommon
, libappindicator-gtk3
, libxshmfence
, libglvnd
, wayland
}:

let
  pname = "electron_13-bin";
  version = "13.6.9";
  hashes = {
    armv7l-linux = "e70cf80ac17850f3291c19a89235c59a7a6e0c791e7965805872ce584479c419";
    aarch64-linux = "cb570f77e46403a75b99740c41b297154f057dc3b9aa75fd235dccc5619972cf";
    x86_64-linux = "5e29701394041ba2acd8a9bb042d77967c399b8fe007d7ffbd1d3e6bfdb9eb8a";
    i686-linux = "7c31b60ee0e1d9966b8cf977528ace91e10ce25bb289a46eabbcf6087bee50e6";
    x86_64-darwin = "3393f0e87f30be325b76fb2275fe2d5614d995457de77fe00fa6eef2d60f331e";
    aarch64-darwin = "8471777eafc6fb641148a9c6acff2ea41c02a989d4d0a3a460322672d85169df";
    headers = "0vvizddmhprprbdf6bklasz6amwc254bpc9j0zlx23d1pgyxpnhc";
  };

  meta = with lib; {
    description = "Cross platform desktop application shell";
    homepage = "https://github.com/electron/electron";
    license = licenses.mit;
    maintainers = with maintainers; [ travisbhartwell manveru prusnak ];
    platforms = [ "x86_64-darwin" "x86_64-linux" "armv7l-linux" "aarch64-linux" ]
      ++ optionals (versionAtLeast version "11.0.0") [ "aarch64-darwin" ]
      ++ optionals (versionOlder version "19.0.0") [ "i686-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    knownVulnerabilities = optional (versionOlder version "22.0.0" || versions.major version == "23") "Electron version ${version} is EOL";
  };

  fetcher = vers: tag: hash: fetchurl {
    url = "https://github.com/electron/electron/releases/download/v${vers}/electron-v${vers}-${tag}.zip";
    sha256 = hash;
  };

  headersFetcher = vers: hash: fetchurl {
    url = "https://artifacts.electronjs.org/headers/dist/v${vers}/node-v${vers}-headers.tar.gz";
    sha256 = hash;
  };

  tags = {
    x86_64-linux = "linux-x64";
    armv7l-linux = "linux-armv7l";
    aarch64-linux = "linux-arm64";
    x86_64-darwin = "darwin-x64";
  } // lib.optionalAttrs (lib.versionAtLeast version "11.0.0") {
     aarch64-darwin = "darwin-arm64";
  } // lib.optionalAttrs (lib.versionOlder version "19.0.0") {
    i686-linux = "linux-ia32";
  };

  get = as: platform: as.${platform.system} or (throw "Unsupported system: ${platform.system}");

  common = platform: {
    inherit pname version meta;
    src = fetcher version (get tags platform) (get hashes platform);
    passthru.headers = headersFetcher version hashes.headers;
  };

  electronLibPath = with lib; makeLibraryPath (
    [ libuuid at-spi2-atk at-spi2-core libappindicator-gtk3 wayland ]
    ++ optionals (versionAtLeast version "9.0.0") [ libdrm mesa ]
    ++ optionals (versionOlder version "10.0.0") [ libXScrnSaver ]
    ++ optionals (versionAtLeast version "11.0.0") [ libxkbcommon ]
    ++ optionals (versionAtLeast version "12.0.0") [ libxshmfence ]
    ++ optionals (versionAtLeast version "17.0.0") [ libglvnd ]
  );

  linux = {
    buildInputs = [ glib gtk3 ];

    nativeBuildInputs = [
      unzip
      makeWrapper
      wrapGAppsHook
    ];

    dontWrapGApps = true; # electron is in lib, we need to wrap it manually

    dontUnpack = true;
    dontBuild = true;

    installPhase = ''
      mkdir -p $out/lib/electron $out/bin
      unzip -d $out/lib/electron $src
      ln -s $out/lib/electron/electron $out/bin
    '';

    postFixup = ''
      patchelf \
        --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
        --set-rpath "${atomEnv.libPath}:${electronLibPath}:$out/lib/electron" \
        $out/lib/electron/electron \
        ${lib.optionalString (lib.versionAtLeast version "15.0.0") "$out/lib/electron/chrome_crashpad_handler" }

      wrapProgram $out/lib/electron/electron "''${gappsWrapperArgs[@]}"
    '';
  };

  darwin = {
    nativeBuildInputs = [
      makeWrapper
      unzip
    ];

    buildCommand = ''
      mkdir -p $out/Applications
      unzip $src
      mv Electron.app $out/Applications
      mkdir -p $out/bin
      makeWrapper $out/Applications/Electron.app/Contents/MacOS/Electron $out/bin/electron
    '';
  };
in
  stdenv.mkDerivation (
    (common stdenv.hostPlatform) //
    (if stdenv.isDarwin then darwin else linux)
  )
