{ opts, lib, config, ... }:

let
  cfg = config.myHome.editors.zed;
in
{
  programs.zed-editor = lib.mkIf (cfg.package != null) {
    enable = true;
    package = cfg.package;
  };

  home.activation.zedSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/zed/settings.json $HOME/.config/zed/settings.json
  '';

  home.activation.zedKeymap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/zed/keymap.json $HOME/.config/zed/keymap.json
  '';
}
