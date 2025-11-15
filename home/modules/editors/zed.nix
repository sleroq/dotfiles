{ pkgs, opts, lib, inputs', config, ... }:

let
  cfg = config.myHome.editors.zed;
in
{
  programs.zed-editor = lib.mkIf (cfg.package != null) {
    enable = true;
    package = cfg.package;
  };

  home.activation.zed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/zed $HOME/.config
  '';
}