{ pkgs, opts, lib, ... }:

with lib;
{
  home.activation.picom = hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/picom.conf $HOME/.config
  '';

  home.packages = with pkgs; [
    picom
  ];
}
