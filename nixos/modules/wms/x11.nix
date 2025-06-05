{ pkgs, ... }: {
  services.libinput = {
    # Enable touchpad support (enabled default in most desktopManager)
    enable = true;
  
    # Disabling mouse acceleration
    mouse = { accelProfile = "flat"; };
  
    # Disabling touchpad acceleration
    touchpad = { accelProfile = "flat"; };
  };

  services.xserver = {
    enable = true;

    xkb = {
      layout = "us,ru";
      variant = "";
      options = "grp:lctrl_lwin_toggle,ctrl:nocaps";
    };

    excludePackages = [ pkgs.xterm ];
  };
}
