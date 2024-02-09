{ pkgs, opts, lib, ... }:

with lib;
{
  home.activation.swaync = hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/swaync $HOME/.config
  '';

  home.packages = with pkgs; [
    swaynotificationcenter
  ];
}
