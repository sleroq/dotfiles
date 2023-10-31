{ pkgs, lib, opts, ... }:

with lib;
{
  home.activation.eww = hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/eww $HOME/.config
  '';

  programs.ncmpcpp = {
    enable = true;
  };

  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    eww-wayland
    gawk
    pamixer

    font-awesome
    (nerdfonts.override { fonts = [ "JetBrainsMono" "Ubuntu" "Agave" ]; })
  ];
}
