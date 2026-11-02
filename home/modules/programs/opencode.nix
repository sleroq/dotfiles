{
  pkgs,
  lib,
  config,
  opts,
  inputs',
  ...
}:

let
  cfg = config.myHome.programs.opencode;
  settingsDefaults = builtins.fromJSON (builtins.readFile ../../config/opencode/opencode.json);
  settings = (pkgs.formats.json { }).generate "opencode.json" (
    settingsDefaults
    // {
      plugins = map (
        plugin:
        if builtins.isString plugin && lib.hasPrefix "./" plugin then
          "${opts.realConfigs}/opencode/${lib.removePrefix "./" plugin}"
        else
          plugin
      ) settingsDefaults.plugins;
    }
  );
  opencode = pkgs.writeShellScriptBin "opencode" ''
    exec ${inputs'.llm-agents.packages.opencode2}/bin/opencode2 "$@"
  '';
in
{
  options.myHome.programs.opencode.enable = lib.mkEnableOption "OpenCode AI coding assistant";

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.beans
      opencode
    ];

    home.activation.removeLegacyOpencode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run rm -f "$HOME/.bun/bin/opencode"
    '';

    home.activation.opencodeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p $HOME/.config/opencode

      for path in ${opts.realConfigs}/opencode/*; do
        case "$path" in
          */opencode.json) continue ;;
        esac
        $DRY_RUN_CMD ln -sfn $VERBOSE_ARG "$path" "$HOME/.config/opencode/"
      done
      $DRY_RUN_CMD ln -sfn $VERBOSE_ARG ${settings} "$HOME/.config/opencode/opencode.json"
      $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
          ${opts.realConfigs}/agents/AGENTS.md "$HOME/.config/opencode/AGENTS.md"

      if [ -z "$DRY_RUN_CMD" ]; then
        ${pkgs.bun}/bin/bun install --frozen-lockfile \
          --cwd ${opts.realConfigs}/opencode/plugins/direnv
      fi
    '';
  };
}
