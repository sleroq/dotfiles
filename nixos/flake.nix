{
  description = "Sleroq's NixOS system configuration";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  inputs.nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

  inputs.hyprland.url = "github:hyprwm/Hyprland/0bd541f2fd902dbfa04c3ea2ccf679395e316887";

  outputs = { self, nixpkgs, nixpkgs-unstable, ... }@inputs:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
    overlay-unstable = final: prev: {
      unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
    };
  in {
    overlays = import ./overlays { inherit inputs; inherit (self.outputs) outputs; };
    packages = import ./pkgs { inherit pkgs; inherit (nixpkgs.lib) lib; };

    nixosConfigurations.sleroq-international = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; inherit (self) outputs; };
      modules = [
        ({ ... }: { nixpkgs.overlays = [ overlay-unstable ]; })
        ./configuration.nix
      ];
    };
  };
}
