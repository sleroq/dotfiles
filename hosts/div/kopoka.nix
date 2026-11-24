{
  config,
  inputs',
  ...
}:
{
  age.secrets.kopokaEnv = {
    owner = "kopoka";
    group = "kopoka";
    file = ./secrets/kopokaEnv;
  };

  age.secrets.kopokaOtlpEnv.file = ../../shared/secrets/kopokaOtlpEnv;

  users.users.kopoka = {
    isSystemUser = true;
    group = "kopoka";
  };
  users.groups.kopoka = { };

  sleroq.cloudflared.tunnels.music.routes."kopoka.cum.army" = "http://127.0.0.1:8080";

  services.starflake.deployments.kopoka = {
    source.url = "github:sleroq/kopoka";
    initialPackage = inputs'.kopoka.packages.default;
    build.allowLocalBuild = false;
    runtime = {
      exec = [ "bin/kopoka" ];
      user = "kopoka";
      group = "kopoka";
      environmentFiles = [
        config.age.secrets.kopokaEnv.path
        config.age.secrets.kopokaOtlpEnv.path
      ];
      environment = {
        THUMBNAIL_BASE_URL = "https://kopoka.cum.army";
        OTEL_EXPORTER_OTLP_ENDPOINT = "https://cum.army/otlp/kopoka";
      };
    };
    state.dataDir = "/var/lib/kopoka";
    poll.interval = "10m";
  };
}
