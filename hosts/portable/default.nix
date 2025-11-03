{ agenixModule, inputs', realConfigs, self, ... }:

{
  system = {
    stateVersion = "25.05";
  };

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      substituters = [
        "https://nix-community.cachix.org"
        "https://cache.nixos.org/"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
  };

  users.users.sleroq = {
    name = "sleroq";
    home = "/Users/sleroq";
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    sharedModules = [
      ../../home/modules/programs
      ../../home/modules/editors
      ../../home/modules/gaming.nix
      agenixModule
    ];

    extraSpecialArgs = {
      inherit inputs' self;
      secrets = import ./secrets/default.nix;
      opts = {
        inherit realConfigs;
      };
    };
  };
}
