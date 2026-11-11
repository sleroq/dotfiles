{ config, pkgs, ... }:
{
  services.garage = {
    enable = true;
    package = pkgs.garage_2;
    environmentFile = config.age.secrets.garageEnv.path;
    settings = {
      replication_factor = 1;
      rpc_bind_addr = "127.0.0.1:3901";
      rpc_public_addr = "127.0.0.1:3901";
      s3_api = {
        api_bind_addr = "127.0.0.1:3900";
        s3_region = "garage";
        public_endpoint = "https://s3.cum.army";
        public_endpoint_path_style = true;
      };
    };
  };

  age.secrets.garageEnv.file = ./secrets/garageEnv;
  systemd.services.garage.restartTriggers = [ config.age.secrets.garageEnv.file ];

  sleroq.cloudflared.tunnels.music.routes."s3.cum.army" = "http://127.0.0.1:3900";
}
