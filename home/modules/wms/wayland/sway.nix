{ pkgs, opts, lib, ... }:

with lib; {
  imports = [
    ../../programs/wofi.nix
    ../../programs/eww.nix
    ../../programs/swaync.nix
  ];

  home.activation.sway = hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/sway/* $HOME/.config/sway/
  '';

  programs = {
    swaylock.enable = true;
  };

  services = {
    swayidle.enable = true;
    swayosd.enable = true;
    cliphist.enable = true;
  };

  home.packages = with pkgs; [
    stalonetray
    cliphist
    swayidle
    swaykbdd
    swayr
  ];
}
