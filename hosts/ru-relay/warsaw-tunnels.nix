{
  config,
  pkgs,
  secrets,
  ...
}:

let
  warsawAddress = secrets.warsawAddress;
  tls = {
    enabled = true;
    server_name = "waw.cum.army";
  };
  multiplex = {
    enabled = true;
    protocol = "h2mux";
    max_connections = 4;
    min_streams = 8;
  };
  settings = {
    log.level = "warn";
    inbounds = [
      {
        type = "direct";
        tag = "vless-in";
        listen = "127.0.0.1";
        listen_port = 12083;
        network = "tcp";
        override_address = "127.0.0.1";
        override_port = 2080;
      }
    ];
    outbounds = [
      {
        type = "vless";
        tag = "vless-tunnel";
        server = warsawAddress;
        server_port = 2443;
        uuid = "REPLACED_AT_RUNTIME";
        network = "tcp";
        inherit tls multiplex;
      }
      {
        type = "block";
        tag = "block";
      }
    ];
    route = {
      rules = [
        {
          inbound = [ "vless-in" ];
          action = "route";
          outbound = "vless-tunnel";
        }
      ];
      final = "block";
    };
  };
  template = pkgs.writeText "ru-warsaw-tunnels-template.json" (builtins.toJSON settings);
  render = pkgs.writeShellScript "render-ru-warsaw-tunnels" ''
    set -eu
    ${pkgs.jq}/bin/jq --slurpfile auth "$CREDENTIALS_DIRECTORY/auth" \
      '.outbounds[0].uuid = $auth[0].vless' \
      ${template} > /run/ru-warsaw-tunnels/config.json
  '';
in
{
  age.secrets.warsawTunnelAuth.file = ./secrets/warsawTunnelAuth.age;

  systemd.services.ru-warsaw-tunnels = {
    description = "Multiplexed RU-to-Warsaw VLESS tunnel client";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "simple";
      DynamicUser = true;
      RuntimeDirectory = "ru-warsaw-tunnels";
      RuntimeDirectoryMode = "0700";
      UMask = "0077";
      LoadCredential = "auth:${config.age.secrets.warsawTunnelAuth.path}";
      ExecStartPre = render;
      ExecStart = "${pkgs.sing-box}/bin/sing-box run -c /run/ru-warsaw-tunnels/config.json";
      Restart = "on-failure";
      RestartSec = 3;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      CapabilityBoundingSet = [ ];
    };
  };
}
