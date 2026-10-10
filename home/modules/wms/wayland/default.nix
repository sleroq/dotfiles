{
  inputs',
  pkgs,
  lib,
  config,
  opts,
  self,
  ...
}:

let
  cfg = config.myHome.wms.wayland;
in
{
  imports = [ ./dwl.nix ];

  options.myHome.wms.wayland = {
    enable = lib.mkEnableOption "Default wayland stuff";
    hyprland = {
      enable = lib.mkEnableOption "Hyprland";
      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Extra Lua configuration loaded before the main Hyprland config";
      };
      gamemode = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to enable gamemode (disable animations) by default";
      };
    };
    sway.enable = lib.mkEnableOption "Sway";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.kanshi.enable = true;

      # TODO: remove tofi?
      programs.tofi = {
        enable = true;
        settings = {
          background-color = "#000A";
          border-width = 0;
          font = "monospace";
          height = "100%";
          num-results = 5;
          outline-width = 0;
          padding-left = "35%";
          padding-top = "35%";
          result-spacing = 25;
          width = "100%";
        };
      };
      services.cliphist.enable = true;
      home.activation.vicinae = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ -d "${config.xdg.configHome}/vicinae" ] && [ ! -L "${config.xdg.configHome}/vicinae" ]; then
          $DRY_RUN_CMD rmdir $VERBOSE_ARG "${config.xdg.configHome}/vicinae"
        fi

        $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
          ${opts.realConfigs}/vicinae "${config.xdg.configHome}/vicinae"
      '';
      systemd.user.services.vicinae = {
        Unit = {
          Description = "Vicinae Launcher Daemon";
          After = [ "graphical-session.target" ];
          Requires = [ "dbus.socket" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.vicinae}/bin/vicinae server --replace";
          Restart = "always";
          RestartSec = 60;
          KillMode = "process";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      # Packages universal for all window managers
      home.packages = with pkgs; [
        vicinae
        wl-clipboard
        # cava
        grim
        slurp

        waypaper
        awww
      ];

      # TODO: Do not enable on desktop
      # services.batsignal = {
      #   enable = true;
      #   extraArgs = ["-p" "-f" "99"];
      # };
    })

    (lib.mkIf (cfg.hyprland.enable || cfg.dwl.enable) (
      import ../../programs/flameshot.nix { inherit pkgs config; }
    ))
    (lib.mkIf cfg.hyprland.enable (import ../../programs/mic-mute.nix { inherit pkgs; }))

    (lib.mkIf cfg.hyprland.enable (
      import ./hyprland.nix {
        inherit
          pkgs
          opts
          lib
          inputs'
          config
          self
          ;
      }
    ))
    (lib.mkIf cfg.sway.enable (
      import ./sway.nix {
        inherit
          pkgs
          opts
          lib
          self
          ;
      }
    ))
  ];
}
