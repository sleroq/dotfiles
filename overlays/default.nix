{
  nixpkgs-master,
  nixpkgs,
  rust-overlay,
  sb,
}:
let
  inherit (nixpkgs.lib) composeManyExtensions;
in
rec {
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

  broadcast-box = final: _prev: {
    broadcast-box = final.callPackage ../packages/broadcast-box.nix { };
  };

  obsidian-neovide = final: _prev: {
    obsidian-neovide = final.callPackage ../packages/obsidian-neovide.nix { };
  };

  sing-box-subscribe-cli = final: _prev: {
    sing-box-subscribe-cli = final.callPackage ../packages/sing-box-subscribe-cli.nix { };
  };

  trusttunnel-client = final: _prev: {
    trusttunnel-client = final.callPackage ../packages/trusttunnel-client.nix { };
  };

  default = composeManyExtensions [
    sb.overlays.default
    rust-overlay.overlays.default
    code-cursor
    # opencode
    broadcast-box
    obsidian-neovide
    sing-box-subscribe-cli
    trusttunnel-client
  ];
}
