{
  pkgs,
  lib,
  config,
  opts,
  self,
  ...
}:

let
  cfg = config.myHome.programs.opencode;
  opencode2 = self.inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode2;
in
{
  options.myHome.programs.opencode.enable = lib.mkEnableOption "OpenCode AI coding assistant";

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.beans
      opencode2
      (pkgs.writeShellScriptBin "opencode" ''
        exec ${opencode2}/bin/opencode2 "$@"
      '')
    ];

    home.activation.removeLegacyOpencode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run rm -f "$HOME/.bun/bin/opencode" "$HOME/.bun/bin/opencode2"
    '';

    home.activation.opencodeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p $HOME/.config/opencode

      $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
          ${opts.realConfigs}/opencode/* $HOME/.config/opencode/
      $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
          ${opts.realConfigs}/agents/AGENTS.md "$HOME/.config/opencode/AGENTS.md"

      if [ -z "$DRY_RUN_CMD" ]; then
        ${pkgs.bun}/bin/bun install --frozen-lockfile \
          --cwd ${opts.realConfigs}/opencode/plugins/direnv
      fi
    '';
  };
}
