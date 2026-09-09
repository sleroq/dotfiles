{
  self,
  scrcpyPkgs,
  nixpkgs-master,
  nixpkgs,
  rust-overlay,
  sb,
}:
let
  inherit (nixpkgs.lib) composeManyExtensions;
in
rec {
  scrcpy =
    final: prev:
    # Only apply scrcpy overlay on non-Darwin systems
    # (Darwin systems should use scrcpy from their own nixpkgs)
    let
      pkgsScrcpy = import scrcpyPkgs {
        system = final.stdenv.hostPlatform.system;
        config = removeAttrs (prev.config or { }) [ "replaceStdenv" ];
      };
    in
    {
      scrcpy = pkgsScrcpy.scrcpy;
    };

  code-cursor =
    final: prev:
    let
      pkgsMaster = import nixpkgs-master {
        system = final.stdenv.hostPlatform.system;
        config = prev.config or { };
      };
    in
    {
      code-cursor = pkgsMaster.code-cursor;
    };

  broadcast-box = final: prev: {
    broadcast-box = final.callPackage ../packages/broadcast-box.nix { };
  };

  sing-box-subscribe-cli = final: prev: {
    sing-box-subscribe-cli = final.callPackage ../packages/sing-box-subscribe-cli.nix { };
  };

  trusttunnel-client = final: prev: {
    trusttunnel-client = final.callPackage ../packages/trusttunnel-client.nix { };
  };

  default = composeManyExtensions [
    sb.overlays.default
    rust-overlay.overlays.default
    scrcpy
    code-cursor
    # opencode
    broadcast-box
    sing-box-subscribe-cli
    trusttunnel-client
  ];
}
