{ pkgs, opts, lib, ... }:

with lib;
{
  home.activation.swaycons = hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/swaycons $HOME/.config
  '';

  home.packages = with pkgs; [
    swaycons
  ];
}
