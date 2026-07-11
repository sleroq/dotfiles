{
  pkgs,
  lib,
  config,
  opts,
  ...
}:

let
  cfg = config.myHome.programs.opencode;
in
{
  options.myHome.programs.opencode.enable = lib.mkEnableOption "OpenCode AI coding assistant";

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      { home.packages = [ pkgs.beans ]; }

      {
        home.activation.installOpencode2 = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          PATH="${pkgs.bun}/bin:$HOME/.bun/bin:$PATH"
          if ! command -v opencode2 &> /dev/null; then
            run ${pkgs.bun}/bin/bun install -g @opencode-ai/cli@next
          fi
        '';
      }

      {
        home.activation.opencodeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          mkdir -p $HOME/.config/opencode

          $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
              ${opts.realConfigs}/opencode/* $HOME/.config/opencode/
        '';
      }
    ]
  );
}
