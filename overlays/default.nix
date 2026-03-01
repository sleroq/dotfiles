{
  self,
  scrcpyPkgs,
  nixpkgs-master,
  nixpkgs,
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

  default = composeManyExtensions [
    scrcpy
    code-cursor
    # opencode
    broadcast-box
  ];
}
