{ config, pkgs, ... }:
let
  paseoRelay = pkgs.callPackage ../../../packages/paseo-relay.nix { };
in
{
  # Own the persistent links used by the relay-only activation as well as the normal unit.
  environment.etc."systemd/system.control/paseo-relay.service".source = "${
    config.systemd.units."paseo-relay.service".unit
  }/paseo-relay.service";
  environment.etc."systemd/system.control/multi-user.target.wants/paseo-relay.service".source = "${
    config.systemd.units."paseo-relay.service".unit
  }/paseo-relay.service";

  systemd.services.paseo-relay = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    environment = {
      HOME = "/var/lib/paseo-relay";
      RELEASE_TMP = "/run/paseo-relay";
      RELEASE_DISTRIBUTION = "none";
      # The release launcher requires a cookie even with distribution disabled.
      RELEASE_COOKIE = "paseo-relay-standalone";
      PASEO_RELAY_HOST = "127.0.0.1";
      PASEO_RELAY_PORT = "6769";
      PASEO_RELAY_MEMORY_WATERMARK_BYTES = "402653184";
    };
    serviceConfig = {
      DynamicUser = true;
      StateDirectory = "paseo-relay";
      RuntimeDirectory = "paseo-relay";
      WorkingDirectory = "/var/lib/paseo-relay";
      ExecStart = "${paseoRelay}/bin/paseo_relay start";
      Restart = "on-failure";
      RestartSec = 5;
      MemoryMax = "512M";
      CapabilityBoundingSet = "";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
    };
  };

  services.caddy.virtualHosts."relay.sleroq.link".extraConfig = ''
    # The pinned upstream listener registers /ws, not /relay.
    @relay path /ws /health /ready
    handle @relay {
      reverse_proxy localhost:6769
    }
    handle {
      respond "Not found" 404
    }
  '';
}
