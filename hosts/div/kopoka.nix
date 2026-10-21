{
  config,
  inputs',
  pkgs,
  ...
}:
let
  package = inputs'.kopoka.packages.default.overrideAttrs (_: {
    nativeBuildInputs = [ pkgs.go ];
  });
in
{
  age.secrets.kopokaEnv = {
    owner = "kopoka";
    group = "kopoka";
    file = ./secrets/kopokaEnv;
  };

  users.users.kopoka = {
    isSystemUser = true;
    group = "kopoka";
  };
  users.groups.kopoka = { };

  systemd.services.kopoka = {
    description = "Kopoka Telegram Bot";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${package}/bin/kopoka";
      User = "kopoka";
      Group = "kopoka";
      Restart = "always";
      RestartSec = "10s";
      EnvironmentFile = config.age.secrets.kopokaEnv.path;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
    };
  };
}
