{
  description = "Sleroq's NixOS system configuration";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.hyprland = {
    type = "git";
    url = "https://github.com/hyprwm/Hyprland";
    submodules = true;
    ref = "refs/tags/v0.41.0";
  };

  outputs = { self, nixpkgs, ... }@inputs:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in {
    overlays = import ./overlays { inherit inputs; inherit (self.outputs) outputs; };
    packages = import ./pkgs { inherit pkgs; inherit (nixpkgs.lib) lib; };

    nixosConfigurations.sleroq-international = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; inherit (self) outputs; };
      modules = [ ./configuration.nix ];
    };
  };
}
