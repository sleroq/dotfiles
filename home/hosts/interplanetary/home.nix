{ pkgs, scrcpyPkgs, inputs, ... }:

{
  myHome = {
    wms = {
      wayland = {
        hyprland = {
          extraConfig = ''
            # See https://wiki.hyprland.org/Configuring/Monitors/
            monitor = DP-2, 2560x1440@180.00, auto, 1
          '';
          gamemode = true;
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
      ghostty = {
        enable = true;
        package = inputs.ghostty.packages.${pkgs.system}.default;
      };
      wireplumberHacks.enable = true;
      obs.enable = true;
      chromium = {
        enable = true;
        unsafeWebGPU = true;
      };
      teams.enable = true;
      exodus.enable = true;
      extraPackages = [
        pkgs.ollama-rocm
        pkgs.chatbox
        scrcpyPkgs.scrcpy
        inputs.zig.packages.${pkgs.system}.master
        # Temporarily disabled due to upstream test failures; re-enable after picking a working rev
        # inputs.zls.packages.${pkgs.system}.default
        pkgs.bottles
      ];
    };
  };
}
