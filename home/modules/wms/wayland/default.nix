{ pkgs, opts, lib, ... }:

with lib;
{
  imports = [
    ./sway.nix
    # ./hyprland.nix
  ];

  home.activation.picom = hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/picom.conf $HOME/.config
  '';

  # Packages universal for all window managers
  home.packages = with pkgs; [
    cava
    grim
    slurp

    # lxappearence won't work without GDK_BACKEND=x11
    # so waiting for nwg-look package or lxappearence fix
    # nwg-look 
  ];

}
