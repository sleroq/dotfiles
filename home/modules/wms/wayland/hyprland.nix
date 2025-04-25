{ pkgs, opts, lib, inputs, config, ... }:

let
  hyprscroller = pkgs.callPackage ../../../packages/hyprscroller.nix {
    lib = lib;
    pkg-config = pkgs.pkg-config;
    hyprland = inputs.hyprland.packages.x86_64-linux.hyprland;
    cmake = pkgs.cmake;
    fetchFromGitHub = pkgs.fetchFromGitHub;
  };
in
{
  imports = [
    ../../programs/eww.nix
    ../../programs/flameshot.nix
    # ../../programs/ironbar.nix
  ];

  home.activation.hyprland = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p $HOME/.config/hypr

    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
        ${opts.realConfigs}/hypr/* $HOME/.config/hypr/
  '';

  # home.file."${config.xdg.configHome}/hypr/extra-config.conf" = {
  #   text = "plugin = ${inputs.hy3.packages.x86_64-linux.hy3}/lib/libhy3.so";
  # };
  home.file."${config.xdg.configHome}/hypr/extra-config.conf" = {
    text = "plugin = ${hyprscroller}/lib/hyprscroller.so";
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

  # Hypr* stuff breaking with no reason as always
  # TODO: Maybe move back to hyprlock when it's fixed

  # programs.hyprlock = {
  #   enable = true;
    # settings = {
    #   general = {
    #     disable_loading_bar = true;
    #     grace = 5;
    #     hide_cursor = true;
    #     no_fade_in = false;
    #   };
    #
    #   background = [
    #     {
    #       path = "screenshot";
    #       blur_passes = 3;
    #       blur_size = 8;
    #     }
    #   ];
    #
    #   input-field = [
    #     {
    #       size = "200, 50";
    #       position = "0, -80";
    #       monitor = "";
    #       dots_center = true;
    #       fade_on_empty = false;
    #       font_color = "rgb(202, 211, 245)";
    #       inner_color = "rgb(91, 96, 120)";
    #       outer_color = "rgb(24, 25, 38)";
    #       outline_thickness = 5;
    #       placeholder_text = "<span foreground=\"##cad3f5\">lol kek</span>";
    #       shadow_passes = 2;
    #     }
    #   ];
    # };
  # };

  # TODO: remove after release of homemanager
  # Workaround for https://github.com/nix-community/home-manager/issues/5899#issuecomment-2498226238
  systemd.user.services.hypridle.Unit.After = lib.mkForce "graphical-session.target";

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
