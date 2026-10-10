{
  pkgs,
  inputs',
  lib,
  ...
}:

let
  bottles = pkgs.bottles.override {
    bottles-unwrapped = pkgs.bottles-unwrapped.override {
      python3Packages = pkgs.python3Packages.overrideScope (
        _final: prev: {
          patool = prev.patool.overridePythonAttrs (_old: {
            doCheck = false;
          });
        }
      );
    };
  };
in
{
  age.identityPaths = [ "/var/lib/agenix-key.txt" ];

  myHome = {
    wms = {
      wayland = {
        sway.enable = false;
        dwl.enable = true;
        hyprland = {
          enable = lib.mkForce false;
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
      datagrip.enable = false;
      zed.enable = false;
    };
    gaming = {
      etterna.enable = false;
      osu.enable = true;
      minecraft.enable = true;
    };

    programs = {
      remmina.enable = false;
      pi.enable = true;
      kitty.enable = true;
      obs.enable = true;
      chromium.enable = true;
      opencode.enable = true;
      exodus.enable = true;
      mangohud.enable = true;
      extraPackages = with pkgs; [
        obsidian
        # ollama-rocm
        # chatbox
        scrcpy
        # Match the Zig release supported by the locked ZLS.
        inputs'.zig.packages."0.17.0"
        inputs'.zls.packages.default
        bottles
        qFlipper
        # blender
        # android-studio-full
      ];
    };
  };

  programs.obs-studio.plugins = [ (pkgs.callPackage ../../packages/obs-moq.nix { }) ];

  programs.caelestia = {
    settings = {
      bar.statusIcons = [
        {
          id = "lockStatus";
          enabled = true;
        }
        {
          id = "bluetooth";
          enabled = true;
        }
      ];
    };
  };

  services.easyeffects.enable = false;
}
