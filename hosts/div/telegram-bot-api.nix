{ config, pkgs, ... }:
{
  age.secrets.telegramBotApiEnv.file = ./secrets/telegramBotApiEnv;

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 8081 ];

  systemd.services.telegram-bot-api = {
    description = "Telegram Bot API server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    restartTriggers = [ config.age.secrets.telegramBotApiEnv.file ];
    serviceConfig = {
      DynamicUser = true;
      StateDirectory = "telegram-bot-api";
      WorkingDirectory = "/var/lib/telegram-bot-api";
      EnvironmentFile = config.age.secrets.telegramBotApiEnv.path;
      ExecStart = "${pkgs.telegram-bot-api}/bin/telegram-bot-api --local --http-port=8081 --dir=/var/lib/telegram-bot-api --temp-dir=/var/lib/telegram-bot-api";
      Restart = "on-failure";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
    };
  };
}
