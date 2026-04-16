{
  lib,
  config,
  opts,
  pkgs,
  ...
}:

let
  cfg = config.myHome.programs.pi;
in
{
  options.myHome.programs.pi = {
    enable = lib.mkEnableOption "Pi coding agent";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home.activation.installPi = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          PATH="${pkgs.bun}/bin:$HOME/.bun/bin:$PATH"
          if ! command -v pi &> /dev/null; then
            run ${pkgs.bun}/bin/bun install -g @mariozechner/pi-coding-agent
          fi
        '';
      }

      {
        home.activation.piConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          mkdir -p $HOME/.pi/agent

          $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
              ${opts.realConfigs}/pi/agent/* $HOME/.pi/agent/
        '';
      }
    ]
  );
}
