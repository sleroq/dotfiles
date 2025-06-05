{ config, pkgs, ... }:

let
  profiles = {
    performance = {
      cpuEnergyPerfPolicy = "performance";
      platformProfile = "performance";
      cpuBoost = true;
      cpuHwpDynBoost = true;
    };
    balanced = {
      cpuEnergyPerfPolicy = "balance_performance";
      platformProfile = "balance_performance";
      cpuBoost = true;
      cpuHwpDynBoost = true;
    };
    power-save = {
      cpuEnergyPerfPolicy = "power";
      platformProfile = "low-power";
      cpuBoost = false;
      cpuHwpDynBoost = false;
    };
  };

  selectedProfile = profiles.${config.sleroq.batteryLife.profile};
in {
  options.sleroq.batteryLife = {
    profile = pkgs.lib.mkOption {
      type = pkgs.lib.types.enum [ "performance" "balanced" "power-save" ];
      default = "balanced";
      description = "Performance profile for battery management";
    };
  };

  config = {
    environment.systemPackages = [
      pkgs.powertop
    ];

    services.power-profiles-daemon.enable = false;
    services.thermald.enable = true;

    services.tlp = {
      enable = true;
      settings = {
        CPU_ENERGY_PERF_POLICY_ON_AC = selectedProfile.cpuEnergyPerfPolicy;
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
        PLATFORM_PROFILE_ON_AC = selectedProfile.platformProfile;
        PLATFORM_PROFILE_ON_BAT = "low-power";
        RUNTIME_PM_ON_AC = "auto";
        RUNTIME_PM_ON_BAT = "auto";
        CPU_BOOST_ON_AC = if selectedProfile.cpuBoost then "1" else "0";
        CPU_BOOST_ON_BAT = "0";
        CPU_HWP_DYN_BOOST_ON_AC = if selectedProfile.cpuHwpDynBoost then "1" else "0";
        CPU_HWP_DYN_BOOST_ON_BAT = "0";
      };
    };
  };
}
