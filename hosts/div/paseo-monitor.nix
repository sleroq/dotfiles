{
  config,
  pkgs,
  inputs',
  ...
}:
let
  inherit (import ../../modules/paseo/packages.nix { inherit pkgs inputs'; }) paseo;
  checker = pkgs.buildGo127Module {
    pname = "paseo-schedule-checker";
    version = "0.1.0";
    src = ../../modules/paseo/schedule-checker;
    vendorHash = null;
  };
in
{
  services.prometheus.exporters.node.extraFlags = [
    "--collector.textfile.directory=/var/lib/paseo-schedule-checker"
  ];

  systemd.services.paseo-schedule-checker = {
    description = "Check Paseo schedule results for monitoring";
    environment.HOME = "/home/${config.services.paseo.user}";
    serviceConfig = {
      Type = "oneshot";
      User = config.services.paseo.user;
      StateDirectory = "paseo-schedule-checker";
      StateDirectoryMode = "0755";
      ExecStart = "${checker}/bin/paseo-schedule-checker -paseo ${paseo}/bin/paseo -output /var/lib/paseo-schedule-checker/paseo.prom -state /var/lib/paseo-schedule-checker/initialized-at";
    };
  };

  systemd.timers.paseo-schedule-checker = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2m";
      OnUnitActiveSec = "5m";
    };
  };
}
