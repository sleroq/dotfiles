{ agenixModule, inputs', realConfigs, self, ... }:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    sharedModules = [
      ./modules/wms/wayland
      ./modules/programs
      ./modules/editors
      ./modules/gaming.nix
      ./shared
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


