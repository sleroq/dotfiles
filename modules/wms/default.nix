{ lib, config, pkgs, ... }: 
with lib;
let
  cfg = config.sleroq.wms;
  sddm-astronaut = pkgs.sddm-astronaut.override { 
    # embeddedTheme = "hyprland_kath";
  };
in
{
  options.sleroq.wms.enable = mkEnableOption "window manager stack (SDDM, portals)";

  imports = [
    ./wayland.nix
    ./x11.nix
  ];

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      xdg-utils
      sddm-astronaut
    ];

    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
      package = pkgs.kdePackages.sddm;
      theme = "sddm-astronaut-theme";
      extraPackages = [ sddm-astronaut ];
    };
  };
}
