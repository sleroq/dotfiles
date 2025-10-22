{ pkgs, opts, lib, inputs', config, self, ... }:

with lib;
let
  hyprlandScripts = {
    followMouseToggle = pkgs.writeShellScriptBin "hypr-follow-mouse-toggle" ''
      #!/usr/bin/env sh
      
      FOLLOWMOUSE=$(hyprctl getoption input:follow_mouse | awk 'NR==1{print $2}')
      
      if [ "$FOLLOWMOUSE" = 1 ] ; then
          hyprctl --batch "\
              keyword input:follow_mouse 0;\
              keyword input:float_switch_override_focus 0"
          exit
      fi
      
      hyprctl reload
    '';

    gamemode = pkgs.writeShellScriptBin "hypr-gamemode" ''
      #!/usr/bin/env sh
      
      HYPRGAMEMODE=$(hyprctl getoption animations:enabled | awk 'NR==1{print $2}')
      
      if [ "$HYPRGAMEMODE" = 1 ] ; then
          hyprctl --batch "\
              keyword animations:enabled 0;\
              keyword decoration:shadow:enabled 0;\
              keyword decoration:blur:enabled 0;\
              keyword misc:vfr 0;\
              keyword general:border_size 1;\
              keyword decoration:rounding 0"
          exit
      else
          hyprctl --batch "\
              keyword animations:enabled 1;\
              keyword decoration:shadow:enabled 1;\
              keyword decoration:blur:enabled 1;\
              keyword misc:vfr 1;\
              keyword general:border_size 2;\
              keyword decoration:rounding 1"
          exit
      fi
    '';
  };
in
mkMerge [
  (import ../../programs/flameshot.nix { inherit pkgs config; })
  (import ../../programs/mic-mute.nix { inherit pkgs; })
  (import ../../programs/caelestia.nix { inherit pkgs; })
  {
    home.activation.hyprland = hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p $HOME/.config/hypr

      $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
          ${opts.realConfigs}/hypr/* $HOME/.config/hypr/
    '';



    home.file."${config.xdg.configHome}/hypr/extra-config.conf" = {
      text = mkMerge [
        "plugin = ${inputs'.hy3.packages.hy3}/lib/libhy3.so"
        (mkIf config.myHome.wms.wayland.hyprland.gamemode ''
          exec = hypr-gamemode
        '')
        (mkIf (config.myHome.gaming.osu.enable && config.myHome.gaming.osu.enableTearing) ''
          windowrulev2 = immediate, class:^(osu!)$
        '')
        config.myHome.wms.wayland.hyprland.extraConfig
      ];
    };

    home.file."${config.xdg.configHome}/hypr/xdph.conf" = {
      text = ''
        screencopy {
          max_fps = 60
        }
      '';
    };

    home.packages = with pkgs; [
      hyprland-per-window-layout
      inputs'.hy3.packages.hy3
      hyprpolkitagent
      hyprpicker

      jq
      socat

      # hyprland scripts
      hyprlandScripts.followMouseToggle
      hyprlandScripts.gamemode
    ];
  }
]
