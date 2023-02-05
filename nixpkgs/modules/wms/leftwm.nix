
{ config, pkgs, opts, ... }:

with config;
{
  home.activation.leftwm = hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/leftwm $HOME/.config
  '';
}
