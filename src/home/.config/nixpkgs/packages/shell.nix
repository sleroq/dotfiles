# file: default.nix
{ pkgs ? import <nixpkgs> {}, }:
rec {
  myProject = pkgs.stdenv.mkDerivation {
    name = "smth";
    version = "dev-0.1";
    buildInputs = with pkgs; [
      (callPackage ./my-lf { })
    ];
  };
}
