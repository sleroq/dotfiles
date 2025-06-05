{ ... }:

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
    programs = {
      obs.enable = true;
      chromium = {
        enable = true;
        unsafeWebGPU = true;
      };
      anytype = {
        enable = true;
        version = "0.46.8";
        hash = "sha256-lmMmGNXybJ33ODcSfguSPM05gun5CbKUcW3ZFo6jdVE=";
      };
    };
  };
}
