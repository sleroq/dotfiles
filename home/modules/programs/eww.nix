{ pkgs, lib, opts, inputs, ... }:

with lib;
{
  home.activation.eww = hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/eww $HOME/.config
  '';

  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    inputs.eww.packages.${pkgs.system}.eww
    gawk
    pamixer
    killall

    (nerdfonts.override { fonts = [ "Noto" "DaddyTimeMono" ]; })
  ];
}
