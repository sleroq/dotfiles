{ lib, config, pkgs, ... }:
with lib;
let
  cfg = config.sleroq.batteryLife;
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

  selectedProfile = profiles.${cfg.profile};
in {
  options.sleroq.batteryLife = {
    enable = mkEnableOption "battery life tuning via TLP and thermald";

    profile = mkOption {
      type = types.enum [ "performance" "balanced" "power-save" ];
      default = "balanced";
      description = "Performance profile for battery management";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.powertop
    ];

    services = {
      power-profiles-daemon.enable = false;
      thermald.enable = true;

      tlp = {
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
  };
}
