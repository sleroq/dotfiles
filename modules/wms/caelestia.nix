{ config, lib, ... }:
{
  config = lib.mkMerge [
    {
      home-manager.sharedModules = [
        {
          options.programs.caelestia.package = lib.mkOption {
            apply =
              package:
              package.overrideAttrs (old: {
                patches = (old.patches or [ ]) ++ [ ../../packages/caelestia-system-pam.patch ];
              });
          };
        }
      ];
    }
    # System services follow the shell's Home Manager enablement.
    (lib.mkIf
      (lib.any (home: home.programs.caelestia.enable) (lib.attrValues config.home-manager.users))
      {
        services.upower.enable = true;
        services.power-profiles-daemon.enable = true;
        security.pam.services.caelestia = { };
      }
    )
  ];
}
