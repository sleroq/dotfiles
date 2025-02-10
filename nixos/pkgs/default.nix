{ pkgs , lib }: {
  matebook-charge-limit = pkgs.callPackage ./matebook-charge-limit.nix { inherit lib; };
}
