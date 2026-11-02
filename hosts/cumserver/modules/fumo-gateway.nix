{
  config,
  inputs,
  ...
}:
let
  cfg = config.services.fumo-gateway;
in
{
  imports = [ inputs.fumo-gateway.nixosModules.default ];

  age.secrets.fumoGatewayEnv.file = ../secrets/fumoGatewayEnv;

  services.fumo-gateway = {
    enable = true;
    environmentFile = config.age.secrets.fumoGatewayEnv.path;
    settings = {
      clients.pi.key_env = "FUMO_PI_KEY";
      upstreams.codex = {
        base_url = "https://api.openai.com/v1";
        auth = {
          provider = "codex";
          credentials_dir = "/var/lib/fumo-gateway/credentials";
        };
      };
    };
  };

  # Reuse upstream configuration, user, and state; Starflake owns the process.
  systemd.services.fumo-gateway.enable = false;
  services.starflake.deployments.fumo-gateway = {
    source.url = "github:sleroq/fumo-gateway";
    initialPackage = cfg.package;
    runtime = {
      exec = [
        "bin/fumo-gateway"
        "--config"
        "${cfg.configFile}"
      ];
      user = "fumo-gateway";
      group = "fumo-gateway";
      # Keep /admin/ private: Caddy forwards only the inference routes below.
      environmentFiles = [ cfg.environmentFile ];
    };
    state.directories = [ "fumo-gateway" ];
    health.checks.http.url = "http://127.0.0.1:8318/healthz";
    poll.interval = "10m";
    update.retainGenerations = 3;
  };

  # Login must precede the first reconciliation: a failed initialPackage is
  # journaled by Starflake and is not automatically attempted again.
  systemd.services.starflake-reconcile-fumo-gateway.unitConfig.ConditionPathExists =
    "/var/lib/fumo-gateway/credentials/codex.json";

  systemd.services.starflake-app-fumo-gateway = {
    restartTriggers = [ config.age.secrets.fumoGatewayEnv.file ];
    serviceConfig.StateDirectoryMode = "0700";
  };

  services.caddy.virtualHosts."fumo.cum.army".extraConfig = ''
    @inference path /v1/models /v1/responses
    handle @inference {
      reverse_proxy 127.0.0.1:8318 {
        flush_interval -1
      }
    }
    handle {
      respond 404
    }
  '';
}
