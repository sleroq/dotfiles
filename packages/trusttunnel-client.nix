{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  releaseInfo = builtins.fromJSON (builtins.readFile ./trusttunnel-client.json);
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "trusttunnel-client";
  version = releaseInfo.version;

  src =
    let
      releases = {
        x86_64-linux = {
          platform = "linux-x86_64";
          hash = releaseInfo.hashes."linux-x86_64";
        };
        aarch64-linux = {
          platform = "linux-aarch64";
          hash = releaseInfo.hashes."linux-aarch64";
        };
        x86_64-darwin = {
          platform = "macos-universal";
          hash = releaseInfo.hashes."macos-universal";
        };
        aarch64-darwin = {
          platform = "macos-universal";
          hash = releaseInfo.hashes."macos-universal";
        };
      };
      release = releases.${stdenvNoCC.hostPlatform.system};
    in
    fetchurl {
      url = "https://github.com/TrustTunnel/TrustTunnelClient/releases/download/v${finalAttrs.version}/trusttunnel_client-v${finalAttrs.version}-${release.platform}.tar.gz";
      inherit (release) hash;
    };

  installPhase = ''
    runHook preInstall

    install -Dm755 trusttunnel_client $out/bin/trusttunnel_client
    install -Dm755 setup_wizard $out/bin/setup_wizard
    install -Dm644 LICENSE $out/share/licenses/trusttunnel-client/LICENSE

    runHook postInstall
  '';

  meta = {
    description = "CLI client for TrustTunnel VPN protocol";
    homepage = "https://github.com/TrustTunnel/TrustTunnelClient";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "trusttunnel_client";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
})
