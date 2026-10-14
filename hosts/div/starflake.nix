{
  config,
  inputs,
  pkgs,
  ...
}:
{
  system.extraDependencies = [ inputs.starflake.outPath ];

  services.starflake = {
    enable = true;
    deployments.music-link = {
      source = {
        url = "github:sleroq/music-link/main";
        package = "all";
      };
      initialPackage = inputs.music-link.lib.${pkgs.stdenv.hostPlatform.system}.makePackage {
        themes = [
          "base"
          "daylight"
          "phosphor"
        ];
        defaultTheme = "phosphor";
      };
      runtime = {
        exec = [ "bin/music-link" ];
        environment.MUSIC_LINK_SITE_URL = "https://${config.sleroq.navidrome.cloudflared.hostname}";
      };
      health = {
        checks.http = {
          url = "http://127.0.0.1:8787/_music-link/assets/";
          expectedStatus = 200;
        };
        stabilizationPeriod = "30s";
        timeout = "2m";
      };
      poll.interval = "10m";
    };
  };

  # The exporter deliberately requires loopback. Expose a separate proxy
  # through the private Tailscale firewall interface, never the public WAN.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 9599 ];
  systemd.sockets.starflake-metrics-proxy = {
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "9599" ];
  };
  systemd.services.starflake-metrics-proxy = {
    requires = [ "starflake-metrics.service" ];
    after = [ "starflake-metrics.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd 127.0.0.1:${toString config.services.starflake.metrics.port}";
      DynamicUser = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
    };
  };

  systemd.services.starflake-reconcile-music-link = {
    after = [ "navidrome.service" ];
    wants = [ "navidrome.service" ];
  };
}
