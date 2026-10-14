{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.paseo;
  home = "/home/${cfg.user}";
  sharedMcp = builtins.fromJSON (builtins.readFile ../../home/config/pi/agent/mcp.json);
  mcpDefaults = (pkgs.formats.json { }).generate "paseo-pi-mcp.json" (
    sharedMcp
    // {
      mcpServers =
        (
          if cfg.pi.cloudflare.enable then
            sharedMcp.mcpServers
          else
            builtins.removeAttrs sharedMcp.mcpServers [
              "cloudflare"
              "cloudflare-docs"
            ]
        )
        // {
          chrome-android = sharedMcp.mcpServers.chrome-android // {
            enabled = false;
          };
          exa = sharedMcp.mcpServers.exa // {
            command = "${home}/.pi/agent/npm/node_modules/.bin/exa-mcp-server";
            args = [ ];
          };
        };
    }
  );
in
{
  options.services.paseo.pi.cloudflare.enable = lib.mkEnableOption "Cloudflare Pi MCP servers";

  config = lib.mkIf cfg.enable {
    environment.etc."paseo/pi-settings.json".source = ../../home/config/pi/agent/settings.json;
    environment.etc."paseo/pi-mcp.json".source = mcpDefaults;
    environment.etc."paseo/pi-profile.mjs".source = ./pi-profile.mjs;
    systemd.tmpfiles.rules = [
      "d ${home}/.pi 0700 ${cfg.user} users -"
      "d ${home}/.pi/agent 0700 ${cfg.user} users -"
    ];
  };
}
