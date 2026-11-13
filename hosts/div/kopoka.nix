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

  users.users.kopoka = {
    isSystemUser = true;
    group = "kopoka";
  };
  users.groups.kopoka = { };

  services.starflake.deployments.kopoka = {
    source.url = "github:sleroq/kopoka";
    initialPackage = inputs'.kopoka.packages.default;
    runtime = {
      exec = [ "bin/kopoka" ];
      user = "kopoka";
      group = "kopoka";
      environmentFiles = [ config.age.secrets.kopokaEnv.path ];
    };
    poll.interval = "10m";
  };
}
