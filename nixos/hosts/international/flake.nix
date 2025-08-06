{
  description = "Sleroq's NixOS system configuration (laptop)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  # inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
  inputs.nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

  # inputs.hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1&ref=refs/tags/v0.50.1";
  inputs.hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
  inputs.agenix.url = "github:ryantm/agenix";

  outputs = { self, nixpkgs, nixpkgs-unstable, agenix, ... }@inputs:
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
        (_: { nixpkgs.overlays = [ overlay-unstable ]; })
        ./configuration.nix
        ../shared
        agenix.nixosModules.default
      ];
    };
  };
}
