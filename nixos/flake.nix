{
  description = "Sleroq's NixOS system configuration";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  # inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
  inputs.nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

  inputs.hyprland.url = "github:hyprwm/Hyprland/29e2e59";

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
    packages = import ./pkgs { inherit pkgs; inherit (nixpkgs.lib) lib; };

    # nixosConfigurations.sleroq-international = nixpkgs.lib.nixosSystem {
    #   inherit system;
    #   specialArgs = { inherit inputs; inherit (self) outputs; };
    #   modules = [
    #     ({ ... }: { nixpkgs.overlays = [ overlay-unstable ]; })
    #     ./international.nix
    #   ];
    # };

    nixosConfigurations.sleroq-interplanetary = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; inherit (self) outputs; };
      modules = [
        ({ ... }: { nixpkgs.overlays = [ overlay-unstable ]; })
        ./intergalactic.nix
      ];
    };
  };
}
