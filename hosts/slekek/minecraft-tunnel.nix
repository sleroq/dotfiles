{
  config,
  lib,
  pkgs,
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

  networking.networkmanager.dispatcherScripts = lib.mkIf config.slekek.serverMode [
    {
      source = pkgs.writeShellScript "frp-prefer-wired" ''
        iface="$1"
        action="$2"
        if [ "$action" != "up" ] && [ "$action" != "dhcp4-change" ]; then
          exit 0
        fi
        case "$iface" in
          en*|eth*) ;;
          *) exit 0 ;;
        esac
        if ! ${pkgs.systemd}/bin/systemctl is-active --quiet frp-minecraft-reverse.service; then
          exit 0
        fi
        wired_ip=$(${pkgs.iproute2}/bin/ip -4 -o addr show dev "$iface" scope global | ${pkgs.gawk}/bin/awk '{split($4, a, "/"); print a[1]; exit}')
        [ -n "$wired_ip" ] || exit 0
        if ! ${pkgs.iproute2}/bin/ss -tnH state established '( dport = :7444 )' | ${pkgs.gnugrep}/bin/grep -qF "$wired_ip:"; then
          ${pkgs.systemd}/bin/systemctl restart frp-minecraft-reverse.service
        fi
      '';
    }
  ];
}
