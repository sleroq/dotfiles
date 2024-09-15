{ pkgs, ... }: {
  imports = [
    ./wayland.nix
    ./x11.nix
  ];

  environment.systemPackages = [
    pkgs.xdg-utils
    (pkgs.unstable.where-is-my-sddm-theme.override { variants = [ "qt5" ]; })
  ];

  services.displayManager.sddm = {
    enable = true;
    package = pkgs.libsForQt5.sddm;
    theme = "where_is_my_sddm_theme_qt5";
  };
}
