{ pkgs, inputs', ... }:

let
  bottles = pkgs.bottles.override {
    bottles-unwrapped = pkgs.bottles-unwrapped.override {
      python3Packages = pkgs.python3Packages.overrideScope (_final: prev: {
        patool = prev.patool.overridePythonAttrs (_old: {
          doCheck = false;
        });
      });
    };
  };
in
{
  age.identityPaths = [ "/var/lib/agenix-key.txt" ];

  myHome = {
    wms = {
      wayland = {
        sway.enable = true;
        hyprland = {
          extraConfig = ''
            -- See https://wiki.hypr.land/Configuring/Basics/Monitors/
            hl.monitor({
              output = "DP-1",
              mode = "2560x1440@180.00",
              position = "auto",
              scale = 1,
            })
          '';
          gamemode = false;
        };
      };
    };
    editors = {
      datagrip.enable = true;
      zed.enable = true;
    };
    gaming = {
      etterna.enable = true;
      osu.enable = true;
      minecraft.enable = true;
    };

    programs = {
      pi.enable = true;
      kitty.enable = true;
      obs.enable = true;
      chromium = {
        enable = true;
        unsafeWebGPU = true;
      };
      opencode.enable = true;
      teams.enable = true;
      exodus.enable = true;
      mangohud.enable = true;
      extraPackages = with pkgs; [
        obsidian
        # ollama-rocm
        # chatbox
        scrcpy
        inputs'.zig.packages.master
        inputs'.zls.packages.default
        bottles
        qFlipper
        # blender
        # android-studio-full
      ];
    };
  };

  programs.caelestia = {
    settings = {
      bar.status = {
        showBattery = false;
        showBluetooth = true;
        showNetwork = false;
      };
    };
  };

  services.easyeffects.enable = false;
}
