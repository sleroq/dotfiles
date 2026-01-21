{ self, scrcpyPkgs, nixpkgs-master, nixpkgs-beans, nixpkgs }:
let
  inherit (nixpkgs.lib) composeManyExtensions;
in
rec {
  beans = final: prev:
    let
      nixpkgsBeans = import nixpkgs-beans {
        system = final.stdenv.hostPlatform.system;
        config = prev.config or {};
      };
    in {
      beans = nixpkgsBeans.beans;
    };

  scrcpy = final: prev:
    let
      pkgsScrcpy = import scrcpyPkgs {
        system = final.stdenv.hostPlatform.system;
        config = prev.config or {};
      };
    in {
      scrcpy = pkgsScrcpy.scrcpy;
    };

  code-cursor = final: prev:
    let
      pkgsMaster = import nixpkgs-master {
        system = final.stdenv.hostPlatform.system;
        config = prev.config or {};
      };
    in {
      code-cursor = pkgsMaster.code-cursor;
    };

  opencode = final: prev:
    let
      pkgsMaster = import nixpkgs-master {
        system = final.stdenv.hostPlatform.system;
        config = prev.config or {};
      };
    in {
      opencode = pkgsMaster.opencode;
        # .overrideAttrs (oldAttrs: {
        #   version = "0.15.23";
        #   src = final.fetchFromGitHub {
        #     owner = "sst";
        #     repo = "opencode";
        #     tag = "v0.15.23";
        #     hash = "sha256-0sxqhpfkjffm2c0gsgxzjfcnqp7034a9sdrhjqzfjczrqr8akxrl"; # bad hash
        #   };
        # });
    };

  broadcast-box = final: prev: {
    broadcast-box = final.callPackage ../packages/broadcast-box.nix { };
  };

  default = composeManyExtensions [ scrcpy beans code-cursor opencode broadcast-box ];
}
