{
  description = "Sleroq's NixOS system configuration";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  # inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
  inputs.nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

  inputs.hyprland.url = "github:hyprwm/Hyprland/882f7ad";
  # inputs.hyprland.url = "github:hyprwm/Hyprland";

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
