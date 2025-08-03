{ config, lib, ... }:
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
    
    profiles = {
      enable = lib.mkEnableOption "Stream profiles support";
      
      streamProfiles = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            streamKey = lib.mkOption {
              type = lib.types.str;
              description = "Stream key for the profile";
            };
            
            isPublic = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether the stream is public";
            };
            
            motd = lib.mkOption {
              type = lib.types.str;
              default = "Welcome to the stream!";
              description = "Message of the day for the stream";
            };
          };
        });
        default = {};
        description = "Stream profiles configuration";
        example = {
          "saygex2_1b2e45eb-360c-4d75-a29f-0ecff7e88762" = {
            streamKey = "saygex2";
            isPublic = true;
            motd = "Welcome to my stream!";
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.virtualisation.oci-containers.backend != null;
        message = "OCI containers backend must be configured for Marzban to work";
      }
      {
        assertion = config.services.caddy.enable;
        message = "broadcast-box requires Caddy to be enabled for reverse proxy. Set services.caddy.enable = true";
      }
    ];

    environment.etc = lib.mkIf cfg.profiles.enable (
      lib.mapAttrs' (name: profile: {
        name = "broadcast-box/profiles/${name}";
        value = {
          text = builtins.toJSON {
            streamKey = profile.streamKey;
            isPublic = profile.isPublic;
            motd = profile.motd;
          };
          mode = "0644";
        };
      }) cfg.profiles.streamProfiles
    );

    systemd.tmpfiles.rules = lib.mkIf cfg.profiles.enable [
      "d /etc/broadcast-box 0755 root root -"
      "d /etc/broadcast-box/profiles 0755 root root -"
    ];

    networking.firewall = {
      allowedUDPPorts = [ cfg.udpPort ];
    };

    virtualisation.oci-containers.containers.broadcast-box = {
      inherit (cfg) image;
      autoStart = true;
      pull = "newer";
      
      ports = [
        "127.0.0.1:${toString cfg.port}:8080"
        "0.0.0.0:${toString cfg.udpPort}:${toString cfg.udpPort}/udp"
      ];
      
      volumes = lib.optional cfg.profiles.enable "/etc/broadcast-box/profiles:/broadcast-box/profiles:ro";
      
      environment = {
        HTTP_ADDRESS = ":8080";
        HTTP_PORT = "8080";
        ENABLE_HTTP_REDIRECT = "false";
        UDP_MUX_PORT = toString cfg.udpPort;
        NETWORK_TYPES = "udp4";
        NAT_1_TO_1_IP = (builtins.head config.networking.interfaces.ens3.ipv4.addresses).address;
        NETWORK_TEST_ON_START = "false";
        # DISABLE_STATUS = "true";

        # Options for testing merge request with backend reqwite
        # STREAM_PROFILE_ACTIVE = if cfg.profiles.enable then "true" else "false";
        # HTTP_ADDRESS = "0.0.0.0";
        # DEBUG_INCOMING_API_REQUESTS = "true";
      } // cfg.extraEnvironment;

      environmentFiles = lib.optional (cfg.environmentFile != null) cfg.environmentFile;

      extraOptions = [
        "--hostname=broadcast-box"
        "--sysctl=net.ipv6.conf.all.disable_ipv6=1"
        "--sysctl=net.ipv6.conf.default.disable_ipv6=1"
      ];
    };

    services.caddy.virtualHosts.${cfg.domain} = {
      extraConfig = ''
        reverse_proxy 127.0.0.1:${toString cfg.port}
        
        @websockets {
          header Connection *Upgrade*
          header Upgrade websocket
        }
        reverse_proxy @websockets 127.0.0.1:${toString cfg.port}
        
        header {
          # Enable CORS for WebRTC
          Access-Control-Allow-Origin *
          Access-Control-Allow-Methods "GET, POST, OPTIONS"
          Access-Control-Allow-Headers "Content-Type, Authorization"

          X-Content-Type-Options nosniff
          X-Frame-Options DENY
          X-XSS-Protection "1; mode=block"
          Referrer-Policy strict-origin-when-cross-origin
        }
        
        @options method OPTIONS
        respond @options 204
      '';
    };
  };
} 
