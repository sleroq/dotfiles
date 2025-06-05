{ pkgs, opts, lib, inputs, config, ... }:
lib.mkMerge [
  (import ../../programs/eww.nix { inherit pkgs lib opts; })
  (import ../../programs/flameshot.nix { inherit pkgs lib opts; })
  {
    home.activation.hyprland = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p $HOME/.config/hypr

      $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
          ${opts.realConfigs}/hypr/* $HOME/.config/hypr/
    '';

    home.file."${config.xdg.configHome}/hypr/extra-config.conf" = {
      text = lib.mkMerge [
        "plugin = ${inputs.hy3.packages.x86_64-linux.hy3}/lib/libhy3.so"
        (lib.mkIf config.myHome.wms.wayland.hyprland.gamemode ''
          exec = ~/.config/hypr/scripts/gamemode.sh
        '')
        (lib.mkIf (config.myHome.gaming.osu.enable && config.myHome.gaming.osu.enableTearing) ''
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
      cliphist.enable = true;

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
    ];
  }
]
