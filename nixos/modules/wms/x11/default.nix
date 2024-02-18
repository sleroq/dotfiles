{ pkgs, ... }: {

  services.xserver = {
    enable = true;
    xkb = {
      layout = "us";
      variant = "";
    };
    excludePackages = with pkgs; [ xterm ];
    displayManager.sddm.enable = true;
    desktopManager.plasma5.enable = true;
    # desktopManager.xfce.enable = true;

    libinput = {
      # Enable touchpad support (enabled default in most desktopManager)
      enable = true;

      # Disabling mouse acceleration
      mouse = { accelProfile = "flat"; };

      # Disabling touchpad acceleration
      touchpad = { accelProfile = "flat"; };
    };
  };
}
