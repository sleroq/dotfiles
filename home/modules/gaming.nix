{ inputs', pkgs, lib, config, ... }:

let
  cfg = config.myHome.gaming;
in
{
  options.myHome.gaming = {
    osu = {
      enable = lib.mkEnableOption "osu! lazer";
      enableTearing = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable tearing for osu!";
      };
    };

    etterna.enable = lib.mkEnableOption "etterna";

    minecraft.enable = lib.mkEnableOption "osu! lazer";
  };

  config = lib.mkMerge [
    {
      home.packages = [ pkgs.protonup-qt ];
    }

    (lib.mkIf cfg.osu.enable {
      home.packages = with inputs'.nix-gaming.packages; [
        osu-lazer-bin
        pkgs.opentabletdriver
      ];
    })
    
    (lib.mkIf cfg.etterna.enable { home.packages = [ pkgs.etterna ]; })

    (lib.mkIf cfg.minecraft.enable {
      home.packages = [
        pkgs.prismlauncher
      ];
    })
  ];
}
