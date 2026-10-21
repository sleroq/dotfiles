{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.paseo;
  home = "/home/${cfg.user}";
  sharedOpencode = builtins.fromJSON (builtins.readFile ../../home/config/opencode/opencode.json);
  opencodeConfig = (pkgs.formats.json { }).generate "paseo-opencode.json" (
    sharedOpencode
    // {
      shell = "/etc/profiles/per-user/${cfg.user}/bin/bash";
      plugins = [ ];
      permissions =
        sharedOpencode.permissions
        ++
          map
            (resource: {
              action = "external_directory";
              inherit resource;
              effect = "allow";
            })
            [
              "~/projects/**"
              "~/develop/go/pkg/mod/**"
            ];
      mcp = sharedOpencode.mcp // {
        servers = sharedOpencode.mcp.servers // {
          exa = sharedOpencode.mcp.servers.exa // {
            command = [ "${home}/.pi/agent/npm/node_modules/.bin/exa-mcp-server" ];
          };
        };
      };
    }
  );
in
{
  config = lib.mkIf cfg.enable {
    environment.etc."paseo/opencode.json".source = opencodeConfig;
    systemd.tmpfiles.rules = [
      "d ${home}/.config/opencode 0700 ${cfg.user} users -"
      "d ${home}/.config/opencode/plugins 0700 ${cfg.user} users -"
    ];
  };
}
