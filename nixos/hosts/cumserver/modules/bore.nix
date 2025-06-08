{ config, lib, pkgs, ... }:

let
  cfg = config.cumserver.bore;
  
  # Generate a systemd service for each bore tunnel
  mkBoreService = name: tunnelCfg: {
    "bore-${name}" = {
      description = "Bore tunnel for ${name}";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "bore";
        Group = "bore";
        Restart = "always";
        RestartSec = 5;
        
        ExecStart = let
          args = [
            "${pkgs.bore-cli}/bin/bore"
            "local"
            (toString tunnelCfg.localPort)
            "--to"
            tunnelCfg.server
          ] ++ lib.optionals (tunnelCfg.remotePort != null) [
            "--port"
            (toString tunnelCfg.remotePort)
          ] ++ lib.optionals (tunnelCfg.secret != null) [
            "--secret"
            tunnelCfg.secret
          ] ++ lib.optionals (tunnelCfg.localHost != "localhost") [
            "--local-host"
            tunnelCfg.localHost
          ];
        in
        lib.escapeShellArgs args;
        
        # Environment variables
        Environment = lib.optionals (tunnelCfg.secret != null) [
          "BORE_SECRET=${tunnelCfg.secret}"
        ];
      };
    };
  };
  
  # Generate Caddy virtual host configuration for each tunnel
  mkCaddyVirtualHost = name: tunnelCfg: lib.optionalAttrs tunnelCfg.caddy.enable {
    "${tunnelCfg.caddy.domain}" = {
      extraConfig = ''
        reverse_proxy localhost:${toString tunnelCfg.localPort}
        ${tunnelCfg.caddy.extraConfig}
      '';
    };
  };
  
  tunnelOptions = { name, ... }: {
    options = {
      enable = lib.mkEnableOption "this bore tunnel";
      
      localPort = lib.mkOption {
        type = lib.types.port;
        description = "Local port to expose";
      };
      
      localHost = lib.mkOption {
        type = lib.types.str;
        default = "localhost";
        description = "Local host to expose";
      };
      
      server = lib.mkOption {
        type = lib.types.str;
        default = "bore.pub";
        description = "Remote bore server address";
      };
      
      remotePort = lib.mkOption {
        type = lib.types.nullOr lib.types.port;
        default = null;
        description = "Specific remote port to use (optional)";
      };
      
      secret = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional secret for authentication";
      };
      
      caddy = {
        enable = lib.mkEnableOption "Caddy reverse proxy for this tunnel";
        
        domain = lib.mkOption {
          type = lib.types.str;
          default = "${name}.bore.cum.army";
          description = "Domain name for the Caddy virtual host";
        };
        
        extraConfig = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = "Extra Caddy configuration for this virtual host";
        };
      };
    };
  };
  
  enabledTunnels = lib.filterAttrs (_: tunnel: tunnel.enable) cfg.tunnels;
  
in
{
  options.cumserver.bore = {
    enable = lib.mkEnableOption "bore tunneling service";
    
    tunnels = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule tunnelOptions);
      default = {};
      description = "Bore tunnel configurations";
      example = lib.literalExpression ''
        {
          webapp = {
            enable = true;
            localPort = 3000;
            caddy.enable = true;
            caddy.domain = "webapp.bore.cum.army";
          };
          api = {
            enable = true;
            localPort = 8080;
            server = "bore.pub";
            caddy.enable = true;
            caddy.domain = "api.bore.cum.army";
          };
        }
      '';
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Install bore-cli package
    environment.systemPackages = [ pkgs.bore-cli ];
    
    # Create bore user and group
    users.users.bore = {
      isSystemUser = true;
      group = "bore";
      description = "Bore tunnel service user";
    };
    
    users.groups.bore = {};
    
    # Create systemd services for each enabled tunnel
    systemd.services = lib.mkMerge (lib.mapAttrsToList mkBoreService enabledTunnels);
    
    # Configure Caddy virtual hosts for tunnels with Caddy enabled
    services.caddy.virtualHosts = lib.mkMerge (lib.mapAttrsToList mkCaddyVirtualHost enabledTunnels);
    
    # Ensure Caddy is enabled if any tunnel has Caddy enabled
    cumserver.caddy.enable = lib.mkIf (lib.any (tunnel: tunnel.caddy.enable) (lib.attrValues enabledTunnels)) true;
  };
} 