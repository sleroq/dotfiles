{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";
  inputs.nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
  inputs.agenix.url = "github:ryantm/agenix";
  inputs.secrets = {
    flake = false;
    url = "path:./secrets";
  };

  outputs =
    {
      nixpkgs,
      disko,
      agenix,
      secrets,
      nixos-facter-modules,
      ...
    }:
    {
      nixosConfigurations.cumserver = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          secrets = import "${secrets}/default.nix";
        };
        modules = [
          disko.nixosModules.disko
          agenix.nixosModules.default
          ./configuration.nix
          nixos-facter-modules.nixosModules.facter
          {
            config.facter.reportPath = ./facter.json;
          }
        ];
      };
    };
}
