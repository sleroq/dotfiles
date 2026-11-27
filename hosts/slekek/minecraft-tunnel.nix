{
  config,
  lib,
  secrets,
  ...
}:
{
  age.secrets.minecraftReverseToken.file = ../ru-relay/secrets/minecraftReverseToken.age;

  services.frp.instances.minecraft-reverse = {
    enable = config.slekek.serverMode;
    role = "client";
    settings = {
      serverAddr = secrets.ruRelayAddress;
      serverPort = 7444;
      loginFailExit = false;
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
        protocol = "tcp";
        tcpMux = true;
        poolCount = 8;
        dialServerKeepalive = 30;
        tls = {
          enable = true;
          disableCustomTLSFirstByte = true;
          trustedCaFile = ../../shared/minecraft-reverse.crt;
          serverName = "mine.cum.army";
        };
      };
      proxies = [
        {
          name = "cumcraft-minecraft";
          type = "tcp";
          localIP = "127.0.0.1";
          localPort = 25565;
          remotePort = 12565;
          transport = {
            useCompression = false;
            useEncryption = false;
          };
        }
        {
          name = "cumcraft-bluemap";
          type = "tcp";
          localIP = "127.0.0.1";
          localPort = 8100;
          remotePort = 18100;
          transport = {
            useCompression = false;
            useEncryption = false;
          };
        }
      ];
    };
  };

  systemd.services.frp-minecraft-reverse = lib.mkIf config.slekek.serverMode {
    serviceConfig = {
      LoadCredential = [ "token:${config.age.secrets.minecraftReverseToken.path}" ];
      LimitNOFILE = 65536;
      RestartSec = lib.mkForce 3;
      UMask = "0077";
    };
  };
}
