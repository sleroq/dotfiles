{ ... }:

{
  myHome = {
    wms = {
      wayland = {
        hyprland = {
          extraConfig = ''
            # See https://wiki.hyprland.org/Configuring/Monitors/
            monitor = DP-2, 2560x1440@180.00, auto, 1
          '';
        };
      };
    };
    editors = {
      zed.enable = true;
      cursor.enable = true;
    };
    gaming = {
      etterna.enable = true;
      osu.enable = true;
      minecraft.enable = true;
    };

    programs = {
      anytype = {
        enable = true;
        version = "0.46.8";
        hash = "sha256-lmMmGNXybJ33ODcSfguSPM05gun5CbKUcW3ZFo6jdVE=";
      };
      obs.enable = true;
      chromium = {
        enable = true;
        unsafeWebGPU = true;
      };
      teams.enable = true;
    };
  };
}
