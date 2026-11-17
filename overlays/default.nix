{
  nixpkgs,
  rust-overlay,
  ph,
}:
let
  inherit (nixpkgs.lib) composeManyExtensions;
in
rec {
  broadcast-box = final: _prev: {
    broadcast-box = final.callPackage ../packages/broadcast-box.nix { };
  };

  obsidian-neovide = final: _prev: {
    obsidian-neovide = final.callPackage ../packages/obsidian-neovide.nix { };
  };

  trusttunnel-client = final: _prev: {
    trusttunnel-client = final.callPackage ../packages/trusttunnel-client.nix { };
  };

  nushell = _final: prev: {
    nushell = prev.nushell.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ../packages/patches/nushell-sharp-errors.patch ];
    });
  };

  default = composeManyExtensions [
    ph.overlays.default
    rust-overlay.overlays.default
    broadcast-box
    obsidian-neovide
    trusttunnel-client
    nushell
  ];
}
