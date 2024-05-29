{ pkgs, lib, config, outputs, ... }:
with lib;
let
  cfg = config.programs.dwl;

  wrapperOptions = types.submodule {
    options =
      let
        mkWrapperFeature  = default: description: mkOption {
          type = types.bool;
          inherit default;
          example = !default;
          description = "Whether to make use of the ${description}";
        };
      in {
        base = mkWrapperFeature true ''
          base wrapper to execute extra session commands and prepend a
          dbus-run-session to the Dwl command.
        '';
        gtk = mkWrapperFeature false ''
          wrapGAppsHook wrapper to execute dwl with required environment
          variables for GTK applications.
        '';
    };
  };

  finalPackage = (outputs.packages.dwl-wrapped.override {
    lib = lib;
    extraSessionCommands = cfg.extraSessionCommands;
    extraOptions = cfg.extraOptions;
    withGtkWrapper = cfg.wrapperFeatures.gtk;
    postPatch = cfg.postPatch;
    patches = [
      (pkgs.fetchpatch {
        url = "https://codeberg.org/dwl/dwl-patches/raw/branch/main/patches/autostart/autostart.patch";
        sha256 = "sha256-OGGqnTIpM5bZRUY5j1r8Zy2cDQiLlZKURW5gN56lehY=";
      })
      (pkgs.fetchpatch {
        url = "https://codeberg.org/dwl/dwl-patches/raw/commit/3f9a58cde9e3aa02991b3e5a22d371b153cb1459/pertag/pertag.patch";
        sha256 = "sha256-lyrPaoGop/TcJBiYVTD79nKVfnqadTpOkaafthj/py4=";
      })
      # (pkgs.fetchpatch {
      #   url = "https://codeberg.org/dwl/dwl-patches/raw/branch/main/patches/naturalscrolltrackpad/naturalscrolltrackpad.patch";
      #   sha256 = "sha256-g7eecBbjCLUgd8WxgsPSk7ohJO0mALZ4ijEEDK/H7AI=";
      # })
      # (pkgs.fetchpatch {
      #   url = "https://codeberg.org/dwl/dwl-patches/raw/branch/main/patches/gaps/gaps.patch";
      #   sha256 = "sha256-6FWCJboTOzSZxDePKMsq0yuLbtT3kW1QFwemVr/pS+g=";
      # })
    ];
  });
in {
  options.programs.dwl = {
    enable = mkEnableOption ''
      Dwl - suckless tiling Wayland compositor. You can manually launch
      Dwl by executing "exec dwl" on a TTY. See
      <https://codeberg.org/dwl/dwl/wiki> and
      "man dwl" for more information'';

    wrapperFeatures = mkOption {
      type = wrapperOptions;
      default = { gtk = true; };
      example = { gtk = true; };
      description = ''
        Attribute set of features to enable in the wrapper.
      '';
    };

    extraSessionCommands = mkOption {
      type = types.lines;
      default = "";
      example = ''
        # SDL:
        export SDL_VIDEODRIVER=wayland
        # QT (needs qt5.qtwayland in systemPackages):
        export QT_QPA_PLATFORM=wayland-egl
        export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
        # Fix for some Java AWT applications (e.g. Android Studio),
        # use this if they aren't displayed properly:
        export _JAVA_AWT_WM_NONREPARENTING=1
      '';
      description = ''
        Shell commands executed just before Dwl is started. See
        <https://github.com/swaywm/sway/wiki/Running-programs-natively-under-wayland>
        and <https://github.com/swaywm/wlroots/blob/master/docs/env_vars.md>
        for some useful environment variables.
      '';
    };

    postPatch = mkOption {
      type = types.lines;
      default = "";
      example = ''
        cp ${configFile} config.def.h
      '';
    };

    extraOptions = mkOption {
      type = types.listOf types.str;
      default = [];
      example = [
        "--verbose"
        "--debug"
        "--unsupported-gpu"
      ];
      description = ''
        Command line arguments passed to launch Dwl.
      '';
    };
  };
  
  config = mkIf cfg.enable {
    environment.systemPackages = [ finalPackage ];

    programs.gnupg.agent.pinentryPackage = lib.mkDefault pkgs.pinentry-gnome3;

    # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1050913
    xdg.portal.config.dwl.default = mkDefault [ "wlr" "gtk" ];

    # To make a Dwl session available if a display manager like SDDM is enabled:
    services.displayManager.sessionPackages = [ finalPackage ];

    # From https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/programs/wayland/wayland-session.nix
    security = {
      pam.services.swaylock = {};
    };

    hardware.opengl.enable = mkDefault true;
    fonts.enableDefaultPackages = mkDefault true;

    programs = {
      dconf.enable = mkDefault true;
      xwayland.enable = mkDefault true;
    };

    xdg.portal = {
      enable = mkDefault true;

      extraPortals = [
        # For screen sharing
        pkgs.xdg-desktop-portal-wlr
      ];
    };
  };
}
