{ pkgs, ... }: {
  environment.systemPackages = [
    pkgs.powertop
  ];

  services.power-profiles-daemon.enable = false;
  services.thermald.enable = true;

  services.tlp = {
    enable = true;
    settings = {
      CPU_ENERGY_PERF_POLICY_ON_AC="performance";
      # CPU_ENERGY_PERF_POLICY_ON_AC="power";
      CPU_ENERGY_PERF_POLICY_ON_BAT="power";
      # PLATFORM_PROFILE_ON_AC="low-power";
      PLATFORM_PROFILE_ON_AC="performance";
      PLATFORM_PROFILE_ON_BAT="low-power";
      RUNTIME_PM_ON_AC="auto";
      RUNTIME_PM_ON_BAT="auto";
      CPU_BOOST_ON_AC="1";
      CPU_BOOST_ON_BAT="0";
      CPU_HWP_DYN_BOOST_ON_AC="1";
      CPU_HWP_DYN_BOOST_ON_BAT="0";
    };
  };
}
