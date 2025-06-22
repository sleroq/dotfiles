{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";
  inputs.nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
  inputs.agenix.url = "github:ryantm/agenix";
  inputs.mailserver.url = "git+https://gitlab.com/simple-nixos-mailserver/nixos-mailserver.git/";
  inputs.secrets = {
    flake = false;
    url = "path:./secrets";
  };
  inputs.sleroq-link = {
    url = "github:sleroq/sleroq.link";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.cum-army = {
    url = "github:sleroq/cum.army";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.bayan = {
    url = "github:sleroq/bayan";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.kopoka = {
    url = "git+ssh://git@github.com/sleroq/kopoka";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.spoiler-images = {
    url = "github:sleroq/spoiler-images";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.reactor = {
    url = "github:sleroq/reactor";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.zefxi.url = "github:sleroq/zefxi";
  inputs.sieve = {
    url = "git+ssh://git@github.com/sleroq/sieve";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.slusha.url = "github:sleroq/slusha";

  outputs =
    { nixpkgs
    , disko
    , agenix
    , secrets
    , nixos-facter-modules
    , mailserver
    , reactor
    , sieve
    , slusha
    , spoiler-images
    , zefxi
    , ...
    }@inputs:
    {
      nixosConfigurations.cumserver = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;

          secrets = import "${secrets}/default.nix";
        };
        modules = [
          disko.nixosModules.disko
          agenix.nixosModules.default
          mailserver.nixosModules.default
          reactor.nixosModules.reactor
          sieve.nixosModules.sieve
          slusha.nixosModules.slusha
          zefxi.nixosModules.zefxi
          ./configuration.nix
          nixos-facter-modules.nixosModules.facter
          {
            config.facter.reportPath = ./facter.json;
          }
        ];
      };
    };
}
