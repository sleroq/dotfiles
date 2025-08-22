{ config, lib, pkgs, ... }:

let
  cfg = config.sleroq.webdav;
in
{
  options.sleroq.webdav = {
    enable = lib.mkEnableOption "WebDAV server with custom configuration";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port for the WebDAV server to listen on";
    };

    address = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Address for the WebDAV server to bind to";
    };

    directory = lib.mkOption {
      type = lib.types.path;
      default = "/srv/webdav";
      description = "Directory to serve via WebDAV";
    };

    permissions = lib.mkOption {
      type = lib.types.str;
      default = "CRUD";
      description = "Default permissions (C=Create, R=Read, U=Update, D=Delete)";
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable debug logging";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open firewall port for WebDAV server";
    };

    tls = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable TLS/HTTPS for WebDAV server";
      };

      certFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to TLS certificate file";
      };

      keyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to TLS private key file";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable the upstream WebDAV service
    services.webdav = {
      enable = true;
      settings = {
        address = cfg.address;
        port = cfg.port;
        directory = cfg.directory;
        permissions = cfg.permissions;
        debug = cfg.debug;
        
        # TLS configuration
        tls = cfg.tls.enable;
        cert = lib.mkIf cfg.tls.enable cfg.tls.certFile;
        key = lib.mkIf cfg.tls.enable cfg.tls.keyFile;
        
        # No authentication - empty users list
        users = [];
        
        # Enable CORS for web access
        cors = {
          enabled = true;
          credentials = false;
          allowed_headers = [ "Depth" "Content-Type" "Authorization" ];
          allowed_methods = [ "GET" "POST" "PUT" "DELETE" "PROPFIND" "PROPPATCH" "MKCOL" "COPY" "MOVE" ];
        };
        
        # Logging configuration
        log = {
          format = "console";
          colors = true;
          outputs = [ "stderr" ];
        };
      };
    };

    # Create the WebDAV directory if it doesn't exist
    systemd.tmpfiles.rules = [
      "d ${cfg.directory} 0755 webdav webdav -"
    ];

    # Open firewall port
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };

    # Ensure the webdav user has access to the directory
    users.users.webdav = {
      extraGroups = [ "users" ];
    };
  };
} 