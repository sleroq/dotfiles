{ lib, config, pkgs, ... }:
with lib;
let
  cfg = config.sleroq.workVpn;
in
{
  options.sleroq.workVpn = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable declarative NetworkManager OpenVPN profile for work-vpn.";
    };

    connectionId = mkOption {
      type = types.str;
      default = "work-vpn";
      description = "Connection ID (name) as shown in NetworkManager.";
    };

    username = mkOption {
      type = types.str;
      description = "OpenVPN username to prefill (will be prompted).";
    };

    remotes = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of remote hosts (or IPs) for OpenVPN. Set via secrets.";
    };

    port = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "OpenVPN UDP port. Set via secrets.";
    };

    secretsPath = mkOption {
      type = types.path;
      description = ''
        Directory containing CA, certificate, private key and TLS auth key files.
        Must provide: ca.crt, cert.crt, private.key, tls_auth.key
      '';
    };

    neverDefault = mkOption {
      type = types.bool;
      default = true;
      description = "Do not install default route through VPN (NetworkManager IPv4 never-default).";
    };

    taDir = mkOption {
      type = types.int;
      default = 1;
      description = "tls-auth key direction (OpenVPN ta-dir).";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.networking.networkmanager.enable or false;
        message = "sleroq.workVpn requires networking.networkmanager.enable = true;";
      }
      {
        assertion = cfg.username != "";
        message = "sleroq.workVpn.username must be set.";
      }
      {
        assertion = cfg.port != null;
        message = "sleroq.workVpn.port must be set.";
      }
      {
        assertion = cfg.remotes != [];
        message = "sleroq.workVpn.remotes must be set.";
      }
    ];

    networking.networkmanager.plugins = [ pkgs.networkmanager-openvpn ];

    # Provide secrets via age and reference them from the nmconnection
    age.secrets.workVpnCa = {
      file = cfg.secretsPath + "/ca.crt";
      mode = "0400";
    };
    age.secrets.workVpnCert = {
      file = cfg.secretsPath + "/cert.crt";
      mode = "0400";
    };
    age.secrets.workVpnKey = {
      file = cfg.secretsPath + "/private.key";
      mode = "0400";
    };
    age.secrets.workVpnTa = {
      file = cfg.secretsPath + "/tls_auth.key";
      mode = "0400";
    };

    environment.etc."NetworkManager/system-connections/${cfg.connectionId}.nmconnection" = {
      mode = "0600";
      user = "root";
      group = "root";
      text = ''
        [connection]
        id=${cfg.connectionId}
        type=vpn
        autoconnect=false

        [vpn]
        ca=${config.age.secrets.workVpnCa.path}
        cert=${config.age.secrets.workVpnCert.path}
        key=${config.age.secrets.workVpnKey.path}
        ta=${config.age.secrets.workVpnTa.path}
        ta-dir=${toString cfg.taDir}
        connection-type=password-tls
        dev=tun
        port=${toString cfg.port}
        remote=${concatStringsSep ", " cfg.remotes}
        reneg-seconds=0
        service-type=org.freedesktop.NetworkManager.openvpn
        username=${cfg.username}
        cert-pass-flags=0
        password-flags=2
        challenge-response-flags=2

        [ipv4]
        method=auto
        ${optionalString cfg.neverDefault "never-default=true"}

        [ipv6]
        addr-gen-mode=stable-privacy
        method=disabled

        [proxy]
      '';
    };
  };
}


