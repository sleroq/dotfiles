{ pkgs , lib }: {
  dwl-wrapped = pkgs.callPackage ./dwl-wrapped.nix { inherit lib; };
}
