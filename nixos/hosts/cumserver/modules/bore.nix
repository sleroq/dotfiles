{ config, pkgs, lib, ... }:
let
  cfg = config.cumserver.bore;
in
{
  options.cumserver.bore = {
    enable = lib.mkEnableOption "Bore server";
    
    minPort = lib.mkOption {
      type = lib.types.int;
      default = 8008;
      description = "Minimum port for bore server";
    };
    
    maxPort = lib.mkOption {
      type = lib.types.int;
      default = 8008;
      description = "Maximum port for bore server";
    };
    
    domain = lib.mkOption {
      type = lib.types.str;
      default = "bore.cum.army";
      description = "Domain for bore server reverse proxy";
    };
    
    bindAddr = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "IP address for bore server to bind to";
    };
    
    proxyPort = lib.mkOption {
      type = lib.types.int;
      default = 8008;
      description = "Port to forward from Caddy reverse proxy to bore server";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.caddy.enable;
        message = "Caddy has to be enabled for Bore server to work";
      }
    ];

    systemd.services.bore-server = {
      description = "Bore TCP tunnel server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "bore";
        Group = "bore";
        Restart = "always";
        RestartSec = "5";
        ExecStart = "${pkgs.bore-cli}/bin/bore server --min-port ${toString cfg.minPort} --max-port ${toString cfg.maxPort} --bind-addr ${cfg.bindAddr}";
        
        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
        RestrictNamespaces = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        RemoveIPC = true;
      };
    };

    users.users.bore = {
      isSystemUser = true;
      group = "bore";
      description = "Bore server user";
    };

    users.groups.bore = {};

    services.caddy = {
      virtualHosts = {
        "${cfg.domain}" = {
          extraConfig = ''
            reverse_proxy 127.0.0.1:${toString cfg.proxyPort}
          '';
        };
      };
    };

    networking.firewall = {
      allowedTCPPorts = [ 7835 cfg.proxyPort ];
      allowedTCPPortRanges = [
        { from = cfg.minPort; to = cfg.maxPort; }
      ];
    };
  };
} 