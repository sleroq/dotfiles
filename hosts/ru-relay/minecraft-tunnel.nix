{ config, lib, ... }:
{
  age.secrets = {
    minecraftReverseToken.file = ./secrets/minecraftReverseToken.age;
    minecraftReverseKey.file = ./secrets/minecraftReverseKey.age;
  };

  services.frp.instances.minecraft-reverse = {
    enable = true;
    role = "server";
    settings = {
      bindAddr = "0.0.0.0";
      bindPort = 7444;
      proxyBindAddr = "127.0.0.1";
      allowPorts = [
        { single = 12565; }
        { single = 18100; }
      ];
      maxPortsPerClient = 2;
      auth = {
        method = "token";
        additionalScopes = [
          "HeartBeats"
          "NewWorkConns"
        ];
        tokenSource = {
          type = "file";
          file.path = "/run/credentials/frp-minecraft-reverse.service/token";
        };
      };
      transport = {
        tcpMux = true;
        maxPoolCount = 16;
        tcpKeepalive = 30;
        tls = {
          force = true;
          certFile = ../../shared/minecraft-reverse.crt;
          keyFile = "/run/credentials/frp-minecraft-reverse.service/server-key";
        };
      };
    };
  };

  systemd.services.frp-minecraft-reverse.serviceConfig = {
    LoadCredential = [
      "token:${config.age.secrets.minecraftReverseToken.path}"
      "server-key:${config.age.secrets.minecraftReverseKey.path}"
    ];
    LimitNOFILE = 65536;
    RestartSec = lib.mkForce 3;
    UMask = lib.mkForce "0077";
  };
}
