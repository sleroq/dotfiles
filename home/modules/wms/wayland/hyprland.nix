{ pkgs, opts, lib, inputs, config, ... }:

{
  imports = [
    ../../programs/eww.nix
  ];

  home.activation.hyprland = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p $HOME/.config/hypr

    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/hypr/* $HOME/.config/hypr/
  '';

  home.file."${config.xdg.configHome}/hypr/extra-config.conf" = {
    text = "plugin = ${inputs.hy3.packages.x86_64-linux.hy3}/lib/libhy3.so";
  };

  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        disable_loading_bar = true;
        grace = 5;
        hide_cursor = true;
        no_fade_in = false;
      };

      background = [
        {
          path = "screenshot";
          blur_passes = 3;
          blur_size = 8;
        }
      ];

      input-field = [
        {
          size = "200, 50";
          position = "0, -80";
          monitor = "";
          dots_center = true;
          fade_on_empty = false;
          font_color = "rgb(202, 211, 245)";
          inner_color = "rgb(91, 96, 120)";
          outer_color = "rgb(24, 25, 38)";
          outline_thickness = 5;
          placeholder_text = "<span foreground=\"##cad3f5\">lol kek</span>";
          shadow_passes = 2;
        }
      ];
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
          lock_cmd = "hyprlock";
        };

        listener = [
          {
            timeout = 900;
            on-timeout = "hyprlock";
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
    flameshot

    jq
    socat
  ];
}
