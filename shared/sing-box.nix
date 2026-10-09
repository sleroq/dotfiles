{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  policy = config.sleroq.sing-box;
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
  routeRules = [
    { action = "sniff"; }
    {
      type = "logical";
      mode = "or";
      rules = [
        { protocol = "dns"; }
        { port = 53; }
      ];
      action = "hijack-dns";
    }
    {
      protocol = "bittorrent";
      action = "route";
      outbound = "direct";
    }
  ]
  ++ lib.optional (policy.directProcessNames != [ ]) {
    process_name = policy.directProcessNames;
    action = "route";
    outbound = "direct";
  }
  ++ lib.optional (policy.directDomains != [ ]) {
    domain_suffix = policy.directDomains;
    action = "route";
    outbound = "direct";
  };
in
{
  options.sleroq.sing-box = {
    directDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Host-specific domain suffixes routed directly.";
    };
    directProcessNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Host-specific exact process names routed directly.";
    };
    enableIPv6 = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include an IPv6 TUN address.";
    };
    routeExcludeAddresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Host-specific TUN route exclusions.";
    };
  };

  config = {
    sleroq.sing-box = {
      directDomains = [
        "рф"
        "ru"
        "local"
        "nelocal"
        "frg"
        "frankrg.com"
        "steampowered.com"
        "steamcommunity.com"
        "steamstatic.com"
        "steamcontent.com"
        "steamserver.net"
        "steamusercontent.com"
        "steam-chat.com"
        "valvesoftware.com"
        "energotransbank.com"
        "alt-web.cum.army"
        "reg.cloud"
        "quietplace.xyz"
      ];
      directProcessNames = [
        "steam"
        "steamwebhelper"
      ];
      routeExcludeAddresses = [
        # Keep bootstrap DNS outside the TUN without bypassing system DNS.
        "9.9.9.9/32"
        "185.147.26.212/32"
      ];
    };

    age.secrets.sing-box-subscription-main = {
      file = ./secrets/sing-box-subscription-main;
      mode = "0600";
    };
    age.secrets.sing-box-subscription-cw = {
      file = ./secrets/sing-box-subscription-cw;
      mode = "0600";
    };

    services.sb = {
      enable = true;
      refreshUser = username;
      converterPackage = pkgs.sing-box-subscribe-cli;
      routingMark = if isLinux then 21314 else 0;
      extraCapabilities = lib.optionals (isLinux && policy.directProcessNames != [ ]) [
        "CAP_SYS_PTRACE"
      ];
      subscription = {
        enable = true;
        sources = [
          {
            name = "main";
            urlFile = config.age.secrets.sing-box-subscription-main.path;
            enable = false;
          }
          {
            name = "cw";
            urlFile = config.age.secrets.sing-box-subscription-cw.path;
          }
        ];
      };
      settings = {
        log = {
          disabled = false;
          level = "warn";
          timestamp = true;
        };
        dns = {
          servers = [
            {
              type = "udp";
              tag = "bootstrap-dns";
              server = "9.9.9.9";
              server_port = 53;
            }
            {
              type = "https";
              tag = "remote-dns";
              server = "1.1.1.1";
              server_port = 443;
              tls.server_name = "cloudflare-dns.com";
              detour = "proxy";
            }
            {
              type = "local";
              tag = "local-dns";
            }
          ];
          rules =
            lib.optional (policy.directProcessNames != [ ]) {
              process_name = policy.directProcessNames;
              action = "route";
              server = "local-dns";
              strategy = "ipv4_only";
            }
            ++ lib.optional (policy.directDomains != [ ]) {
              domain_suffix = policy.directDomains;
              action = "route";
              server = "local-dns";
              strategy = "ipv4_only";
            };
          strategy = "ipv4_only";
          final = "remote-dns";
        };
        inbounds = [
          (
            {
              type = "tun";
              address = [ "198.18.0.1/30" ] ++ lib.optional policy.enableIPv6 "fdfe:dcba:9876::1/126";
              auto_route = true;
              route_exclude_address = policy.routeExcludeAddresses;
            }
            // lib.optionalAttrs isLinux {
              # This host's firewall drops TUN-side TCP with the default mixed stack.
              stack = "gvisor";
              auto_redirect = false;
              strict_route = false;
            }
          )
          {
            type = "mixed";
            tag = "mixed-in";
            listen = "127.0.0.1";
            listen_port = 2080;
          }
        ];
        route = {
          rules = routeRules;
          final = "proxy";
          auto_detect_interface = true;
          default_domain_resolver = "bootstrap-dns";
        };
        experimental.cache_file = {
          enabled = false;
          path = "/var/lib/sing-box/clash.db";
        };
      };
    };
  };
}
