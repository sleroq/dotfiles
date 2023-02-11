{ stdenv, fetchurl, lib }:
stdenv.mkDerivation rec {
  pname = "codeium";
  version = "v1.1.37";

  src = fetchurl {
    url = "https://github.com/Exafunction/codeium/releases/download/language-server-v1.1.37/language_server_linux_x64.gz";
    sha256 = "sha256-L8DGe2RkRR3fBdbIX2q8XljU9MfFuD+mIwz/qBC3tVo=";
  };

  phases = [
    "installPhase"
    "preFixup"
    "installCheckPhase"
  ];

  installPhase = ''
    mkdir -p $out/bin
    gzip -d $src -c > $out/bin/language_server
    chmod +x $out/bin/language_server
  '';

  preFixup = ''
    patchelf \
          --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
          $out/bin/language_server
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/language_server -stamp | grep "STABLE_BUILD_SCM_STATUS: clean"
    runHook postInstallCheck
  '';

  meta = with lib; {
    homepage = https://www.codeium.com/;
    description = "Free, ultrafast Copilot alternative.";
    license = licenses.unfree;
    platforms = platforms.linux;
    maintainers = [ "sleroq" ];
  };
}
