{ pkgs, ... }:

{
  myHome = {
    wms = {
      wayland = {
        enable = true;
        hyprland = {
          enable = true;
          extraConfig = ''
            monitor = eDP-1, 1920x1080@60.02700, auto, 1

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
      # zed.enable = true;
      # cursor.enable = true;
      # helix.enable = false;
    };
    gaming.osu.enable = true;
    programs = {
      # wireplumberHacks.enable = true;
      # obs.enable = true;
      chromium = {
        enable = true;
        unsafeWebGPU = true;
      };
      # exodus.enable = true;
      opencode.enable = true;
      extraPackages = with pkgs; [];
    };
  };
}
