{ inputs', pkgs, lib, config, opts, self, ... }:

let
  cfg = config.myHome.wms.wayland;
in
{
  options.myHome.wms.wayland = {
    enable = lib.mkEnableOption "Default wayland stuff";
    hyprland = {
      enable = lib.mkEnableOption "Hyprland";
      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Extra configuration to append to Hyprland config";
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

      services.vicinae.enable = true;

      # Packages universal for all window managers
      home.packages = with pkgs; [
        wl-clipboard
        # cava
        grim
        slurp

        waypaper
        swww
      ];

      # FIXME: batsignal does not work
      services.batsignal = {
        enable = true;
        extraArgs = ["-p" "-f" "99"];
      };
    })

    (import ../../programs/swaync.nix { })
    (lib.mkIf cfg.hyprland.enable (import ./hyprland.nix { inherit pkgs opts lib inputs' config self; }))
    (lib.mkIf cfg.sway.enable (import ./sway.nix { inherit pkgs opts lib self; }))
  ];
}
