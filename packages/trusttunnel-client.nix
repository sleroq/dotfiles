{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "trusttunnel-client";
  version = "1.1.11";

  src =
    let
      releases = {
        x86_64-linux = {
          platform = "linux-x86_64";
          hash = "sha256-AOBUams1hA27krdB3/PaZzKnS/LWxYHgRLtFZ8DZaCU=";
        };
        aarch64-linux = {
          platform = "linux-aarch64";
          hash = "sha256-iA6civ1czn/zjFOXjw6lMP+V5nm8/vacUSeyazaS0RA=";
        };
        x86_64-darwin = {
          platform = "macos-universal";
          hash = "sha256-4sZ6rqlB/Nz8JOyYaBZEYvzqjR9zH2koxJu+8wDc8aM=";
        };
        aarch64-darwin = {
          platform = "macos-universal";
          hash = "sha256-4sZ6rqlB/Nz8JOyYaBZEYvzqjR9zH2koxJu+8wDc8aM=";
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
