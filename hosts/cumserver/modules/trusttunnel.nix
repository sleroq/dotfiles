{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cumserver.trusttunnel;
  certificateDir = "/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/${cfg.domain}";
  installCertificate = pkgs.writeShellScript "trusttunnel-install-certificate" ''
    for _attempt in $(seq 1 60); do
      if test -s ${certificateDir}/${cfg.domain}.crt \
        && test -s ${certificateDir}/${cfg.domain}.key; then
        install -m 0400 -o trusttunnel -g trusttunnel \
          ${certificateDir}/${cfg.domain}.crt /var/lib/trusttunnel/fullchain.pem
        install -m 0400 -o trusttunnel -g trusttunnel \
          ${certificateDir}/${cfg.domain}.key /var/lib/trusttunnel/privkey.pem
        exit 0
      fi
      sleep 2
    done
    echo "Caddy did not provision the ${cfg.domain} certificate" >&2
    exit 1
  '';
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
    cert_chain_path = "/var/lib/trusttunnel/fullchain.pem"
    private_key_path = "/var/lib/trusttunnel/privkey.pem"
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
      after = [ "network-online.target" "caddy.service" ];
      wants = [ "network-online.target" ];
      requires = [ "caddy.service" ];
      serviceConfig = {
        User = "trusttunnel";
        Group = "trusttunnel";
        ExecStartPre = "+${installCertificate}";
        ExecStart = "${pkgs.trusttunnel-endpoint}/bin/trusttunnel_endpoint ${configDir}/vpn.toml ${configDir}/hosts.toml";
        Restart = "on-failure";
        RestartSec = 3;
        StateDirectory = "trusttunnel";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
      };
    };

    systemd.paths.trusttunnel-certificate-refresh = {
      wantedBy = [ "multi-user.target" ];
      pathConfig = {
        PathChanged = "${certificateDir}/${cfg.domain}.crt";
        Unit = "trusttunnel-certificate-refresh.service";
      };
    };
    systemd.services.trusttunnel-certificate-refresh = {
      description = "Reload TrustTunnel after certificate renewal";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.systemd}/bin/systemctl try-restart trusttunnel.service";
      };
    };

    services.caddy.virtualHosts.${cfg.domain}.extraConfig = ''
      respond "Not found" 404
    '';
  };
}
