{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.myHome.wms.wayland.dwl;
  helper = pkgs.callPackage ../../../../packages/dwl-helper { };
  ewwConfig = "${config.xdg.configHome}/eww-dwl";
  wallpaper = "${config.home.homeDirectory}/Pictures/wallpapers/03779_vyoletznebula_3840x2160.jpg";
  sessionUnit = {
    After = [ "graphical-session.target" ];
    PartOf = [ "graphical-session.target" ];
    ConditionEnvironment = "XDG_CURRENT_DESKTOP=dwl";
  };
  launcher = pkgs.writeShellApplication {
    name = "dwl-launcher";
    runtimeInputs = with pkgs; [
      tofi
      findutils
      uwsm
      cliphist
      wl-clipboard
    ];
    text = ''
      case "$1" in
        apps)
          tofi-drun --drun-launch=false | xargs --no-run-if-empty uwsm-app --
          ;;
        run)
          tofi-run | xargs --no-run-if-empty uwsm-app --
          ;;
        clipboard)
          selection=$(cliphist list | tofi --prompt-text history --padding-left='1%')
          if [ -n "$selection" ]; then
            printf '%s\n' "$selection" | cliphist decode | wl-copy
          fi
          ;;
        *)
          echo 'Usage: dwl-launcher apps|run|clipboard' >&2
          exit 1
          ;;
      esac
    '';
  };
in
{
  options.myHome.wms.wayland.dwl.enable = lib.mkEnableOption "the minimal DWL desktop";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      helper
      launcher
      eww
      awww # Current upstream/Nixpkgs name for swww.
      swaylock
      swayidle
      swaynotificationcenter
      playerctl
      wlopm
      wlr-randr
      brightnessctl
      kitty
      nemo
      networkmanagerapplet
      nerd-fonts.symbols-only
    ];
    xdg.configFile."eww-dwl".source = self + /home/config/eww-dwl;

    programs.swaylock = {
      enable = true;
      settings = {
        image = wallpaper;
        scaling = "fill";
        color = "17151d";
        font = "monospace";
        indicator-radius = 80;
        indicator-thickness = 6;
        inside-color = "17151dcc";
        ring-color = "a288b9";
        key-hl-color = "c5a9d6";
        line-uses-inside = true;
        show-failed-attempts = true;
      };
    };

    services.swayidle = {
      enable = true;
      timeouts = lib.mkDefault [
        {
          timeout = 600;
          command = "${lib.getExe pkgs.swaylock} -f";
        }
        {
          timeout = 800;
          command = "${lib.getExe pkgs.wlopm} --off '*'";
          resumeCommand = "${lib.getExe pkgs.wlopm} --on '*'";
        }
        {
          timeout = 1200;
          command = "${pkgs.systemd}/bin/systemctl suspend-then-hibernate";
        }
      ];
      events = {
        before-sleep = "${lib.getExe pkgs.swaylock} -f";
        lock = "${lib.getExe pkgs.swaylock} -f";
        after-resume = "${lib.getExe pkgs.wlopm} --on '*'";
      };
    };

    services.kanshi.settings = [
      {
        profile = {
          name = "desktop";
          outputs = [
            {
              criteria = "DP-1";
              mode = "2560x1440@180Hz";
              position = "0,0";
              scale = 1.0;
            }
          ];
        };
      }
    ];

    services.swaync = {
      enable = true;
      settings = {
        positionX = "right";
        positionY = "top";
        layer = "overlay";
        control-center-layer = "overlay";
        notification-window-width = 360;
        control-center-width = 400;
        timeout = 6;
        timeout-critical = 0;
        keyboard-shortcuts = true;
        widgets = [
          "title"
          "dnd"
          "notifications"
        ];
      };
      style = ''
        * { font-family: sans-serif; font-size: 13px; }
        .control-center, .notification {
          background: #17151d;
          color: #e8e0ed;
          border: 1px solid #a288b9;
          border-radius: 6px;
          padding: 10px;
        }
        button { background: #302737; color: #e8e0ed; border-radius: 4px; }
        button:hover { background: #51415e; }
      '';
    };

    systemd.user.services = {
      dwl-kitty = {
        Unit = sessionUnit // {
          Description = "DWL shared Kitty instance";
        };
        Service = {
          ExecStart = "${lib.getExe pkgs.kitty} --single-instance --instance-group dwl --start-as hidden --override remember_window_size=no";
          Restart = "on-failure";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
      dwl-helper = {
        Unit = sessionUnit // {
          Description = "DWL event-driven desktop bridge";
        };
        Service = {
          Type = "notify";
          ExecStart = "${lib.getExe helper} daemon";
          Environment = [ "DWL_EWW_CONFIG=${ewwConfig}" ];
          Restart = "on-failure";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
      dwl-widgets = {
        Unit = sessionUnit // {
          Description = "DWL sidebar and hover drawers";
          Requires = [ "dwl-helper.service" ];
          After = sessionUnit.After ++ [ "dwl-helper.service" ];
        };
        Service = {
          ExecStart = "${lib.getExe pkgs.eww} --config ${ewwConfig} daemon --no-daemonize --force-wayland";
          ExecStartPost = "${lib.getExe pkgs.eww} --config ${ewwConfig} open-many sidebar top-sensor audio-sensor";
          ExecStop = "${lib.getExe pkgs.eww} --config ${ewwConfig} kill";
          Restart = "on-failure";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
      dwl-wallpaper = {
        Unit = sessionUnit // {
          Description = "DWL wallpaper";
        };
        Service = {
          Type = "notify";
          ExecStart = "${pkgs.awww}/bin/awww-daemon --format bgr";
          ExecStartPost = "${lib.getExe pkgs.awww} img --transition-type none ${wallpaper}";
          Restart = "on-failure";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
      dwl-polkit = {
        Unit = sessionUnit // {
          Description = "DWL authentication agent";
        };
        Service.ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Install.WantedBy = [ "graphical-session.target" ];
      };
      dwl-network-applet = {
        Unit = sessionUnit // {
          Description = "DWL network tray";
        };
        Service.ExecStart = "${pkgs.networkmanagerapplet}/bin/nm-applet --indicator";
        Install.WantedBy = [ "graphical-session.target" ];
      };
      swayidle.Unit.ConditionEnvironment = lib.mkForce [
        "WAYLAND_DISPLAY"
        "XDG_CURRENT_DESKTOP=dwl"
      ];
      swaync.Unit.ConditionEnvironment = lib.mkForce [
        "WAYLAND_DISPLAY"
        "XDG_CURRENT_DESKTOP=dwl"
      ];
      kanshi.Unit.ConditionEnvironment = lib.mkForce [
        "WAYLAND_DISPLAY"
        "XDG_CURRENT_DESKTOP=dwl"
      ];
      caelestia = lib.mkIf config.programs.caelestia.enable {
        Unit.ConditionEnvironment = "XDG_CURRENT_DESKTOP=Hyprland";
      };
    };
  };
}
