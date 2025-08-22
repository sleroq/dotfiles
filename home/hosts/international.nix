_:

{
  myHome = {
    wms = {
      wayland = {
        enable = true;
        hyprland = {
          enable = true;
          extraConfig = ''
            device {
                name = gxtp7863:00-27c6:01e0-touchpad
                accel_profile = adaptive
                sensitivity = 0.5
            }
          '';
          gamemode = true;
        };
      };
    };
    editors = {
      zed.enable = false;
      cursor.enable = false;
      helix.enable = true;
    };
    programs = {
      obs.enable = true;
      chromium = {
        enable = true;
        unsafeWebGPU = true;
      };
      exodus.enable = true;
    };
  };
}


