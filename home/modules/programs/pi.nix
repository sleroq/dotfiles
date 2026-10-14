{
  lib,
  config,
  opts,
  pkgs,
  self,
  ...
}:

let
  cfg = config.myHome.programs.pi;
  sharedMcp = builtins.fromJSON (builtins.readFile ../../config/pi/agent/mcp.json);
  mcpDefaults = (pkgs.formats.json { }).generate "pi-mcp.json" (
    sharedMcp
    // {
      mcpServers =
        if cfg.cloudflare.enable then
          sharedMcp.mcpServers
        else
          builtins.removeAttrs sharedMcp.mcpServers [
            "cloudflare"
            "cloudflare-docs"
          ];
    }
  );
  exaEnv = config.age.secrets.exa-env.path;
  loadExaEnv = ''
    if [ -r ${lib.escapeShellArg exaEnv} ]; then
      . ${lib.escapeShellArg exaEnv}
      export EXA_API_KEY
    fi
  '';
in
{
  options.myHome.programs.pi = {
    enable = lib.mkEnableOption "Pi coding agent";
    cloudflare.enable = lib.mkEnableOption "Cloudflare Pi MCP servers";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ self.inputs.pi.packages.${pkgs.stdenv.hostPlatform.system}.default ];

    home.activation.removeLegacyPi = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run rm -f "${config.xdg.cacheHome}/.bun/bin/pi" "$HOME/.bun/bin/pi"
    '';

    age.secrets.exa-env = {
      file = ../../../shared/secrets/exa-env;
      path = "${config.xdg.configHome}/pi/exa.env";
      mode = "0600";
    };
    home.sessionVariablesExtra = loadExaEnv;
    programs.zsh.envExtra = loadExaEnv;
    programs.bash.initExtra = loadExaEnv;
    programs.nushell.extraEnv = lib.mkAfter ''
      if (${builtins.toJSON exaEnv} | path exists) {
        $env.EXA_API_KEY = (open --raw ${builtins.toJSON exaEnv} | str replace --regex '^EXA_API_KEY=' "" | str replace --regex '\n$' "")
      }
    '';

    home.sessionVariables = {
      PI_FFF_MODE = "override";
    }
    // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
      # OpenCode's built-in "done" sound at the same volume as opencode/tui.json.
      PI_MAIN_NOTIFY_SOUND_CMD = ''afplay -v 0.4 "$HOME/.pi/agent/sounds/bip-bop-01.mp3"'';
    };

    home.activation.piConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p $HOME/.pi/agent

      # Native credentials rotate and must remain private, writable host files.
      for name in auth.json mcp-auth.json; do
        if [ -L "$HOME/.pi/agent/$name" ]; then
          run install -m 600 "$HOME/.pi/agent/$name" "$HOME/.pi/agent/$name.tmp"
          run mv "$HOME/.pi/agent/$name.tmp" "$HOME/.pi/agent/$name"
        fi
      done

      run ${pkgs.nodejs_24}/bin/node ${../../../modules/paseo/pi-profile.mjs} \
        ${opts.realConfigs}/pi/agent/settings.json \
        ${mcpDefaults} \
        "$HOME/.pi/agent" \
        ${opts.realConfigs}/pi/agent/models.json

      for path in ${opts.realConfigs}/pi/agent/*; do
        case "$path" in
          */auth.json|*/mcp-auth.json|*/settings.json|*/mcp.json|*/models.json) continue ;;
        esac
        $DRY_RUN_CMD ln -sfn $VERBOSE_ARG "$path" "$HOME/.pi/agent/"
      done
    '';
  };
}
