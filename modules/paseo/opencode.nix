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
              "~/.config/paseo-opencode2/**"
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
    system.activationScripts.paseoOpencodeConfig.text = ''
      if [ -L "${home}/.config/paseo-opencode2/opencode.jsonc" ] &&
        [ "$(readlink "${home}/.config/paseo-opencode2/opencode.jsonc")" = /etc/paseo/opencode.json ]; then
        rm "${home}/.config/paseo-opencode2/opencode.jsonc"
      fi
    '';
    systemd.tmpfiles.rules = [
      "d ${home}/.config/opencode 0700 ${cfg.user} users -"
      "d ${home}/.config/opencode/plugins 0700 ${cfg.user} users -"
      "d ${home}/.config/paseo-opencode2 0700 ${cfg.user} users -"
      "d ${home}/.config/paseo-opencode2/plugins 0700 ${cfg.user} users -"
    ];
  };
}
