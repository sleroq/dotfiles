{ pkgs, scrcpyPkgs, pkgs-master, ... }:

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
      helix.enable = true;
    };
    gaming = {
      etterna.enable = true;
      osu.enable = true;
      minecraft.enable = true;
    };

    programs = {
      wireplumberHacks.enable = true;
      anytype = {
        enable = true;
        version = "0.47.3";
        hash = "sha256-19VHCezNqWAgkw+5RlvZ31gSiHKPVhHvpRVlifJ9K88=";
      };
      obs.enable = true;
      chromium = {
        enable = true;
        unsafeWebGPU = true;
      };
      teams.enable = true;
      extraPackages = [
        pkgs.ollama-rocm
        pkgs.chatbox
        scrcpyPkgs.scrcpy
        pkgs-master.broadcast-box
      ];
    };
  };
}
