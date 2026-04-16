{
  pkgs,
  lib,
  config,
  opts,
  ...
}:

let
  cfg = config.myHome.programs.pi;
in
{
  options.myHome.programs.pi = {
    enable = lib.mkEnableOption "Pi coding agent";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs."pi-coding-agent" ];

    home.activation.piConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p $HOME/.pi/agent

      $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
          ${opts.realConfigs}/pi/agent/* $HOME/.pi/agent/
    '';
  };
}
