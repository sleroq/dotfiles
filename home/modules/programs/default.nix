{ pkgs, pkgs-old, lib, config, ... }:

let
  cfg = config.myHome.programs;
in
{
  options.myHome.programs = {
    anytype = {
      enable = lib.mkEnableOption "chromium";
      version = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Override version for anytype";
      };
      hash = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Override hash for anytype";
      };
    };
    lf.enable = lib.mkEnableOption "lf file manager";
    zathura.enable = lib.mkEnableOption "Zathura PDF viewer";
    foot = {
      enable = lib.mkEnableOption "Foot terminal";
      default = lib.mkEnableOption "default env";
    };
    mpv.enable = lib.mkEnableOption "MPV";
    ghostty.enable = lib.mkEnableOption "Ghostty";
    wezterm.enable = lib.mkEnableOption "Wezterm"; 
    teams.enable = lib.mkEnableOption "Teams"; 
    obs.enable = lib.mkEnableOption "obs-studio"; 
    chromium = {
      enable = lib.mkEnableOption "chromium";
      unsafeWebGPU = lib.mkEnableOption "unsafe webgpu"; 
    };
    accounting.enable = lib.mkEnableOption "accounting software";
    obinskit.enable = lib.mkEnableOption "ObinsKit";
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "A list of extra packages to install.";
    };
    activity-watch.enable = lib.mkEnableOption "Activity Watch";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.anytype.enable {
      home.packages = [
        (pkgs.callPackage ../../../packages/anytype.nix {
          inherit (cfg.anytype) version hash;
        })
      ];
    })
    (lib.mkIf cfg.lf.enable (import ./lf.nix { inherit pkgs; }))
    (lib.mkIf cfg.zathura.enable (import ./zathura.nix { }))
    (lib.mkIf cfg.foot.enable (import ./foot.nix { inherit pkgs; }))
    (lib.mkIf (cfg.foot.enable && cfg.foot.default) {
      home.sessionVariables.TERMINAL = "foot";
    })
    (lib.mkIf cfg.ghostty.enable (import ./ghostty.nix { }))
    (lib.mkIf cfg.mpv.enable (import ./mpv.nix { inherit pkgs; }))
    (lib.mkIf cfg.wezterm.enable (import ./wezterm.nix { }))
    (lib.mkIf cfg.teams.enable (import ./teams.nix { inherit pkgs; }))
    (lib.mkIf cfg.obs.enable {
      programs.obs-studio = {
        enable = true;
        plugins = with pkgs.obs-studio-plugins; [
          wlrobs
          obs-backgroundremoval
          obs-pipewire-audio-capture
          input-overlay
        ];
      };
    })
    (lib.mkIf cfg.chromium.enable {
      programs.chromium = {
        enable = true;
        commandLineArgs = [
          "--enable-features=VaapiVideoDecoder"
          "--use-angle=vulkan"
          "--ozone-platform=wayland"
        ]
        ++ (lib.optional cfg.chromium.unsafeWebGPU "--enable-unsafe-webgpu");
      };
    })
    (lib.mkIf cfg.accounting.enable {
      home.packages = with pkgs; [
        inputs.paisa.packages.${pkgs.system}.default
        ledger
        beancount
        beancount-language-server
        fava
      ];
    })
    (lib.mkIf cfg.obinskit.enable { home.packages = [ pkgs-old.obinskit ]; })
    (lib.mkIf cfg.activity-watch.enable {
      home.packages = with pkgs; [
        activitywatch
        aw-watcher-afk
        aw-watcher-window
      ];
    })
    (lib.mkIf (cfg.extraPackages != []) { home.packages = cfg.extraPackages; })
  ];
}
