{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "trusttunnel-client";
  version = "1.1.5";

  src =
    let
      releases = {
        x86_64-linux = {
          platform = "linux-x86_64";
          hash = "sha256-dZVXgS56KAGD9yDjc7N08/zLlXWFMs+KlL6pA97CypY=";
        };
        aarch64-linux = {
          platform = "linux-aarch64";
          hash = "sha256-2xfk4vlxLeJpuOMZZJEyRIf+kHfCI+ULYCZo2Ii16B8=";
        };
        x86_64-darwin = {
          platform = "macos-universal";
          hash = "sha256-SvEocDKBsqnbXO2IE4wYB47X2INWNwHq0v92qIpjyX8=";
        };
        aarch64-darwin = {
          platform = "macos-universal";
          hash = "sha256-SvEocDKBsqnbXO2IE4wYB47X2INWNwHq0v92qIpjyX8=";
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
