{ pkgs, lib, config, opts, ... }:

let
  cfg = config.myHome.astGrep;
in
{
  options.myHome.astGrep.enable = lib.mkEnableOption "shared ast-grep rules";

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.ast-grep ];

    home.activation.astGrepConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "$HOME/.config"

      $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
          ${opts.realConfigs}/ast-grep "$HOME/.config/ast-grep"
    '';
  };
}
