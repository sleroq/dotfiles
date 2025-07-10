{ config, pkgs, lib, ... }:
let
  cfg = config.cumserver.podman;
in
{
  options.cumserver.podman.enable = lib.mkEnableOption "Podman container runtime";

  config = lib.mkIf cfg.enable {
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
      
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };

    environment.systemPackages = with pkgs; [
      podman-compose
    ];

    virtualisation.oci-containers.backend = "podman";

    virtualisation.oci-containers.containers = {
      prometheus-podman-exporter = lib.mkIf config.cumserver.monitoring.enable {
        image = "quay.io/navidys/prometheus-podman-exporter:latest";
        autoStart = true;
        ports = [ "127.0.0.1:9882:9882" ];
        volumes = [
          "/run/podman/podman.sock:/run/podman/podman.sock:ro"
        ];
        environment = {
          CONTAINER_HOST = "unix:///run/podman/podman.sock";
        };
        extraOptions = [
          "--security-opt=label=disable"
          "--user=root"
        ];
        cmd = [
          "--collector.enable-all"
        ];
      };
    };

    services.prometheus.scrapeConfigs = lib.mkIf config.cumserver.monitoring.enable [
      {
        job_name = "podman";
        static_configs = [{ targets = [ "127.0.0.1:9882" ]; }];
       }
    ];
  };
} 