{ self, scrcpyPkgs, nixpkgs-master, nixpkgs }:
let
  inherit (nixpkgs.lib) composeManyExtensions;
in
rec {
  scrcpy = final: prev:
    let
      pkgsScrcpy = import scrcpyPkgs {
        system = final.stdenv.hostPlatform.system;
        config = prev.config or {};
      };
    in {
      scrcpy = pkgsScrcpy.scrcpy;
    };

  cursor = final: prev:
    let
      pkgsMaster = import nixpkgs-master {
        system = final.stdenv.hostPlatform.system;
        config = prev.config or {};
      };
    in {
      cursor = pkgsMaster.cursor;
    };

  opencode = final: prev:
    let
      pkgsMaster = import nixpkgs-master {
        system = final.stdenv.hostPlatform.system;
        config = prev.config or {};
      };
    in {
      opencode = pkgsMaster.opencode;
    };

  default = composeManyExtensions [ scrcpy cursor opencode ];
}


