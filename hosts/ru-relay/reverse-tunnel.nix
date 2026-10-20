{ config, lib, ... }:
{
  age.secrets = {
    warsawReverseToken.file = ./secrets/warsawReverseToken.age;
    warsawReverseKey.file = ./secrets/warsawReverseKey.age;
  };

  services.frp.instances.warsaw-reverse = {
    enable = true;
    role = "server";
    settings = {
      bindAddr = "0.0.0.0";
      bindPort = 7443;
      proxyBindAddr = "127.0.0.1";
      allowPorts = [ { single = 12085; } ];
      maxPortsPerClient = 1;
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
        tcpMux = false;
        maxPoolCount = 16;
        tcpKeepalive = 30;
        tls = {
          force = true;
          certFile = ../../shared/warsaw-reverse.crt;
          keyFile = "/run/credentials/frp-warsaw-reverse.service/server-key";
        };
      };
    };
  };

  systemd.services.frp-warsaw-reverse.serviceConfig = {
    LoadCredential = [
      "token:${config.age.secrets.warsawReverseToken.path}"
      "server-key:${config.age.secrets.warsawReverseKey.path}"
    ];
    LimitNOFILE = 65536;
    RestartSec = lib.mkForce 3;
    UMask = lib.mkForce "0077";
  };
}
