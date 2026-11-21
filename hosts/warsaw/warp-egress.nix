{ lib, ... }:

let
  hostAddress = "10.201.40.1";
  localAddress = "10.201.40.2";
  socksPort = 1080;
  warpInterface = "CloudflareWARP";
in
{
  # Only the container's underlay uses Warsaw's public interface.
  boot.kernel.sysctl."net.ipv4.ip_forward" = lib.mkForce 1;
  networking = {
    firewall.filterForward = true;
    nat = {
      enable = true;
      externalInterface = "ens3";
      internalInterfaces = [ "ve-warp-egress" ];
    };
  };

  containers.warp-egress = {
    autoStart = true;
    privateNetwork = true;
    enableTun = true;
    inherit hostAddress localAddress;

    config =
      { ... }:
      {
        system.stateVersion = "26.05";
        nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "cloudflare-warp";
        networking = {
          defaultGateway = {
            address = hostAddress;
            interface = "eth0";
          };
          nameservers = [ "1.1.1.1" ];
          nftables.enable = true;
          firewall.extraInputRules = ''
            iifname "eth0" ip saddr ${hostAddress} tcp dport ${toString socksPort} accept
            iifname "eth0" ip saddr ${hostAddress} meta l4proto udp accept
          '';
        };

        services.cloudflare-warp = {
          enable = true;
          openFirewall = false;
        };

        services.sing-box = {
          enable = true;
          settings = {
            log.level = "warn";
            inbounds = [
              {
                type = "socks";
                listen = localAddress;
                listen_port = socksPort;
              }
            ];
            dns.servers = [
              {
                type = "https";
                tag = "warp-dns";
                server = "1.1.1.1";
                tls.server_name = "cloudflare-dns.com";
                detour = "warp";
              }
            ];
            # Bind the proxy's outbound sockets, including DoH, so losing the
            # WARP interface cannot send user traffic through the veth instead.
            outbounds = [
              {
                type = "direct";
                tag = "warp";
                bind_interface = warpInterface;
              }
            ];
            route = {
              default_domain_resolver = "warp-dns";
              final = "warp";
            };
          };
        };
      };
  };
}
