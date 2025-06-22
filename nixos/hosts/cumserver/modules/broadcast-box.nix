{ config, pkgs, lib, ... }:
let
  cfg = config.cumserver.broadcast-box;
in
{
  options.cumserver.broadcast-box = {
    enable = lib.mkEnableOption "Broadcast Box WebRTC streaming server";
    
    domain = lib.mkOption {
      type = lib.types.str;
      description = "Domain name for Broadcast Box";
      example = "broadcast.example.com";
    };
    
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Internal port for Broadcast Box HTTP server";
    };
    
    udpPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "UDP port for WebRTC traffic";
    };
    
    image = lib.mkOption {
      type = lib.types.str;
      default = "seaduboi/broadcast-box:latest";
      description = "Docker image to use for Broadcast Box";
    };
    
    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to environment file containing sensitive configuration";
    };
    
    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Additional environment variables";
      example = {
        DISABLE_STATUS = "false";
        NETWORK_TEST_ON_START = "false";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Validation: ensure required services are enabled
    assertions = [
      {
        assertion = config.cumserver.podman.enable or config.virtualisation.podman.enable;
        message = "broadcast-box requires Podman to be enabled. Set cumserver.podman.enable = true or virtualisation.podman.enable = true";
      }
      {
        assertion = config.services.caddy.enable;
        message = "broadcast-box requires Caddy to be enabled for reverse proxy. Set services.caddy.enable = true";
      }
    ];

    # Open UDP port in firewall for WebRTC traffic
    networking.firewall = {
      allowedUDPPorts = [ cfg.udpPort ];
    };

    # Configure Podman container as systemd service
    virtualisation.oci-containers.backend = "podman";
    virtualisation.oci-containers.containers.broadcast-box = {
      image = cfg.image;
      autoStart = true;
      
      # Port mappings without host networking
      ports = [
        "127.0.0.1:${toString cfg.port}:8080"
        "0.0.0.0:${toString cfg.udpPort}:${toString cfg.udpPort}/udp"
      ];
      
      # Environment configuration
      environment = {
        # Standard HTTP server binding
        HTTP_ADDRESS = ":8080";
        
        # Disable redirect server
        ENABLE_HTTP_REDIRECT = "false";
        
        # Use specified UDP port
        UDP_MUX_PORT = toString cfg.udpPort;
        
        # Force IPv4 only to avoid IPv6 binding issues
        NETWORK_TYPES = "udp4";
        
        # Configure NAT with server's public IP
        NAT_1_TO_1_IP = (builtins.head config.networking.interfaces.ens3.ipv4.addresses).address;
        
        # Disable network test
        NETWORK_TEST_ON_START = "false";
        
        # Keep status page
        DISABLE_STATUS = "false";
      } // cfg.extraEnvironment;
      
      # Use environment file if provided
      environmentFiles = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
      
      # Standard container options
      extraOptions = [
        "--hostname=broadcast-box"
        # Disable IPv6 in container to prevent binding issues
        "--sysctl=net.ipv6.conf.all.disable_ipv6=1"
        "--sysctl=net.ipv6.conf.default.disable_ipv6=1"
      ];
    };

    # Configure Caddy reverse proxy
    services.caddy.virtualHosts.${cfg.domain} = {
      extraConfig = ''
        # Proxy HTTP traffic to container
        reverse_proxy 127.0.0.1:${toString cfg.port}
        
        # Enable WebSocket support for WebRTC signaling
        @websockets {
          header Connection *Upgrade*
          header Upgrade websocket
        }
        reverse_proxy @websockets 127.0.0.1:${toString cfg.port}
        
        # Security headers
        header {
          # Enable CORS for WebRTC
          Access-Control-Allow-Origin *
          Access-Control-Allow-Methods "GET, POST, OPTIONS"
          Access-Control-Allow-Headers "Content-Type, Authorization"
          
          # Security headers
          X-Content-Type-Options nosniff
          X-Frame-Options DENY
          X-XSS-Protection "1; mode=block"
          Referrer-Policy strict-origin-when-cross-origin
        }
        
        # Handle preflight OPTIONS requests
        @options method OPTIONS
        respond @options 204
      '';
    };
  };
} 