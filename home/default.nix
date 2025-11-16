{ agenixModule, vicinae, inputs', realConfigs, flakeRoot, self, ... }:
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
      vicinae
    ];

    extraSpecialArgs = {
      inherit inputs' self flakeRoot;
      secrets = import ./secrets/default.nix;
      opts = {
        inherit realConfigs flakeRoot;
      };
      enableSshAuthSocket = true;
    };
  };
}
