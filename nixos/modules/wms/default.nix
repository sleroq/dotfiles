{ pkgs,... }: {
  imports = [
    ./wayland.nix
    ./x11.nix
  ];

  environment.systemPackages = with pkgs; [
    xdg-utils
    where-is-my-sddm-theme
  ];

  services.xserver.displayManager.sddm = {
    enable = true;
    theme = "where_is_my_sddm_theme";
  };
}
