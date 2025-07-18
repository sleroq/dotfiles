{ pkgs, opts, lib, inputs, config, ... }:

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
  (import ../../programs/eww.nix { inherit pkgs lib opts; })
  (import ../../programs/flameshot.nix { inherit pkgs config; })
  (import ../../programs/mic-mute.nix { inherit pkgs; })
  {
    home.activation.hyprland = hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p $HOME/.config/hypr

      $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
          ${opts.realConfigs}/hypr/* $HOME/.config/hypr/
    '';



    home.file."${config.xdg.configHome}/hypr/extra-config.conf" = {
      text = mkMerge [
        "plugin = ${inputs.hy3.packages.x86_64-linux.hy3}/lib/libhy3.so"
        (mkIf config.myHome.wms.wayland.hyprland.gamemode ''
          exec = hypr-gamemode
        '')
        (mkIf (config.myHome.gaming.osu.enable && config.myHome.gaming.osu.enableTearing) ''
          windowrulev2 = immediate, class:^(osu!)$
        '')
        config.myHome.wms.wayland.hyprland.extraConfig
      ];
    };

    programs.swaylock = {
      enable = true;
      settings = {
        color = "111111";
        ignore-empty-password = true;
        indicator-radius = "40";
        indicator-thickness = "10";
        inside-clear-color = "222222";
        inside-color = "1d2021";
        inside-ver-color = "ff99441c";
        inside-wrong-color = "ffffff1c";
        key-hl-color = "ffffff80";
        line-clear-color = "00000000";
        line-color = "00000000";
        line-ver-color = "00000000";
        line-wrong-color = "00000000";
        ring-clear-color = "ff994430";
        ring-color = "282828";
        ring-ver-color = "ffffff00";
        ring-wrong-color = "ffffff55";
        separator-color = "22222260";
        text-caps-lock-color = "00000000";
        text-clear-color = "222222";
        text-ver-color = "00000000";
        text-wrong-color = "00000000";
      };
    };

    services = {
      hypridle = {
        enable = true;

        settings = {
          general = {
            after_sleep_cmd = "hyprctl dispatch dpms on";
            ignore_dbus_inhibit = false;
            lock_cmd = "swaylock";
          };

          listener = [
            {
              timeout = 900;
              on-timeout = "swaylock";
            }
            {
              timeout = 1200;
              on-timeout = "hyprctl dispatch dpms off";
              on-resume = "hyprctl dispatch dpms on";
            }
          ];
        };
      };
    };

    home.packages = with pkgs; [
      hyprland-per-window-layout
      inputs.hy3.packages.x86_64-linux.hy3
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
