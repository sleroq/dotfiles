{
  description = "Sleroq's NixOS system configuration (laptop)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  # inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
  inputs.nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

  inputs.hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1&ref=refs/tags/v0.49.0";

  outputs = { self, nixpkgs, nixpkgs-unstable, ... }@inputs:
  let
    system = "x86_64-linux";
    overlay-unstable = final: prev: {
      unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
    };
  in {
    nixosConfigurations.sleroq-international = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; inherit (self) outputs; };
      modules = [
        ({ ... }: { nixpkgs.overlays = [ overlay-unstable ]; })
        ./configuration.nix
        ../shared
      ];
    };
  };
}
