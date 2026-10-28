{
  config,
  lib,
  secrets,
  ...
}:
{
  age.secrets.warsawReverseToken.file = ./secrets/warsawReverseToken.age;

  services.frp.instances.warsaw-reverse = {
    enable = true;
    role = "client";
    settings = {
      serverAddr = secrets.ruRelayAddress;
      serverPort = 7443;
      loginFailExit = false;
      auth = {
        method = "token";
        additionalScopes = [
          "HeartBeats"
          "NewWorkConns"
        ];
        tokenSource = {
          type = "file";
          file.path = "/run/credentials/frp-warsaw-reverse.service/token";
        };
      };
      transport = {
        protocol = "tcp";
        tcpMux = true;
        poolCount = 16;
        # Keep idle work connections alive through the inter-server path.
        dialServerKeepalive = 30;
        tls = {
          enable = true;
          disableCustomTLSFirstByte = true;
          trustedCaFile = ../../shared/warsaw-reverse.crt;
          serverName = "alt-web.cum.army";
        };
      };
      proxies = [
        {
          name = "warsaw-reality";
          type = "tcp";
          localIP = "127.0.0.1";
          localPort = 443;
          remotePort = 12085;
          transport = {
            useCompression = false;
            useEncryption = false;
          };
        }
      ];
    };
  };

  systemd.services.frp-warsaw-reverse.serviceConfig = {
    LoadCredential = [ "token:${config.age.secrets.warsawReverseToken.path}" ];
    LimitNOFILE = 65536;
    RestartSec = lib.mkForce 3;
    UMask = "0077";
  };
}
