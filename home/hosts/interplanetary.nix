{ pkgs, inputs', ... }:

{
  myHome = {
    wms = {
      wayland = {
        hyprland = {
          extraConfig = ''
            # See https://wiki.hyprland.org/Configuring/Monitors/
            monitor = DP-2, 2560x1440@180.00, auto, 1
          '';
          gamemode = false;
        };
      };
    };
    editors = {
      datagrip.enable = false;
      zed.enable = true;
    };
    gaming = {
      etterna.enable = true;
      osu.enable = true;
      minecraft.enable = true;
    };

    programs = {
      ghostty.enable = true;
      kitty.enable = true;
      wireplumberHacks.enable = true;
      obs.enable = true;
      chromium = {
        enable = true;
        unsafeWebGPU = true;
      };
      teams.enable = true;
      exodus.enable = true;
      mangohud.enable = true;
      extraPackages = with pkgs; [
        # ollama-rocm
        # chatbox
        scrcpy
        inputs'.zig.packages.master
        inputs'.zls.packages.default
        bottles
        qFlipper
        android-studio-full
      ];
    };
  };

  programs.caelestia = {
    settings = {
      bar.status = {
        showBattery = false;
        showBluetooth = false;
        showNetwork = false;
      };
    };
  };

  services.easyeffects.enable = true;
}


