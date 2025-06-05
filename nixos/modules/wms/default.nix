{ pkgs, ... }: 
let
  sddm-astronaut = pkgs.sddm-astronaut.override { 
    embeddedTheme = "hyprland_kath";
  };
in
{
  imports = [
    ./wayland.nix
    ./x11.nix
  ];

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
}
