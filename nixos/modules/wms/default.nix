{ pkgs, ... }: {
  imports = [
    ./wayland.nix
    ./x11.nix
  ];

  environment.systemPackages = [
    pkgs.xdg-utils
    pkgs.where-is-my-sddm-theme
  ];

  services.displayManager.sddm = {
    enable = true;
    package = pkgs.kdePackages.sddm;
    theme = "where_is_my_sddm_theme";
  };
}
