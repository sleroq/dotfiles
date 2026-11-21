{
  lib,
  config,
  opts,
  pkgs,
  inputs',
  ...
}:

let
  cfg = config.myHome.programs.pi;
  pi = pkgs.callPackage ../../../packages/pi.nix {
    upstream = inputs'.pi.packages.default;
  };
  herdrPi = pkgs.writeShellScriptBin "pi" ''
    if [ -n "''${HC_TERMINAL_ID:-}" ]; then
      exec ${pi}/bin/pi --skill ${../../config/herdr-core/skills/herdr} "$@"
    fi
    exec ${pi}/bin/pi "$@"
  '';
  settings = ../../config/pi/agent/settings.json;
  sharedMcp = builtins.fromJSON (builtins.readFile ../../config/pi/agent/mcp.json);
  useRadius = cfg.webSearch.provider == "radius";
  radiusWebExposure = if useRadius then "direct" else "hidden";
  mcpServers = sharedMcp.mcpServers // {
    exa = sharedMcp.mcpServers.exa // {
      enabled = !useRadius;
    };
    radius =
      sharedMcp.mcpServers.radius
      // lib.optionalAttrs useRadius { enabled = true; }
      // {
        toolExposure = sharedMcp.mcpServers.radius.toolExposure // {
          tools_webSearch_run = radiusWebExposure;
        };
      };
  };
  mcpDefaults = (pkgs.formats.json { }).generate "pi-mcp.json" (
    sharedMcp
    // {
      mcpServers =
        if cfg.cloudflare.enable then
          mcpServers
        else
          removeAttrs mcpServers [
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
    webSearch.provider = lib.mkOption {
      type = lib.types.enum [
        "exa"
        "radius"
      ];
      default = "exa";
      description = "Web search provider for Pi. Radius uses the organization's Parallel tier.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      (
        if config.myHome.programs.herdr.enable then
          pkgs.symlinkJoin {
            name = "pi-with-herdr-skill";
            paths = [
              herdrPi
              pi
            ];
          }
        else
          pi
      )
    ];

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
      FUMO_BASE_URL = "https://fumo.cum.army/v1";
      PI_FFF_MODE = "override";
      PI_SKIP_VERSION_CHECK = "1";
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
        ${settings} \
        ${mcpDefaults} \
        "$HOME/.pi/agent" \
        ${opts.realConfigs}/pi/agent/models.json

      $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/agents/AGENTS.md "$HOME/.pi/agent/AGENTS.md"
      $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/paseo-skills "$HOME/.pi/paseo-skills"

      for path in ${opts.realConfigs}/pi/agent/*; do
        case "$path" in
          */auth.json|*/mcp-auth.json|*/settings.json|*/mcp.json|*/models.json) continue ;;
        esac
        $DRY_RUN_CMD ln -sfn $VERBOSE_ARG "$path" "$HOME/.pi/agent/"
      done
    '';
  };
}
