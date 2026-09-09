{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cumserver.trusttunnel;
  configDir = pkgs.runCommand "trusttunnel-config" { } ''
    mkdir -p $out
    cat > $out/vpn.toml <<'EOF'
    listen_address = "127.0.0.1:${toString cfg.port}"
    ipv6_available = true
    allow_private_network_connections = false
    credentials_file = "${cfg.credentialsFile}"

    [listen_protocols.http1]
    [listen_protocols.http2]
    [listen_protocols.quic]

    [forward_protocol]
    direct = {}
    EOF

    cat > $out/hosts.toml <<'EOF'
    [[main_hosts]]
    hostname = "${cfg.domain}"
    cert_chain_path = "${cfg.certificateFile}"
    private_key_path = "${cfg.privateKeyFile}"
    EOF
  '';
in
{
  options.cumserver.trusttunnel = {
    enable = lib.mkEnableOption "TrustTunnel endpoint";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "tunnel.cum.army";
      description = "Public TLS and QUIC server name";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8443;
      description = "Loopback port behind the shared Caddy layer 4 listener";
    };

    credentialsFile = lib.mkOption { type = lib.types.path; };
    certificateFile = lib.mkOption { type = lib.types.path; };
    privateKeyFile = lib.mkOption { type = lib.types.path; };
  };

  config = lib.mkIf cfg.enable {
    users.groups.trusttunnel = { };
    users.users.trusttunnel = {
      isSystemUser = true;
      group = "trusttunnel";
    };

    systemd.services.trusttunnel = {
      description = "TrustTunnel endpoint";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        User = "trusttunnel";
        Group = "trusttunnel";
        ExecStart = "${pkgs.trusttunnel-endpoint}/bin/trusttunnel_endpoint ${configDir}/vpn.toml ${configDir}/hosts.toml";
        Restart = "on-failure";
        RestartSec = 3;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
      };
    };
  };
}
