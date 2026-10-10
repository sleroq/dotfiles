{
  pkgs,
  lib,
  config,
  secrets,
  inputs',
  opts,
  ...
}:

let
  cfg = config.myHome.programs;
in
{
  imports = [
    ./hammerspoon.nix
    ./opencode.nix
    ./pi.nix
  ];

  options.myHome.programs = {
    helium.enable = lib.mkEnableOption "helium";
    remmina.enable = lib.mkEnableOption "Remmina";
    lf.enable = lib.mkEnableOption "lf file manager";
    zathura.enable = lib.mkEnableOption "Zathura PDF viewer";

    foot.enable = lib.mkEnableOption "Foot terminal emulator";
    foot.default = lib.mkEnableOption "default env";
    kitty.enable = lib.mkEnableOption "Kitty terminal emulator";
    kitty.default = lib.mkEnableOption "default env";
    wezterm.enable = lib.mkEnableOption "Wezterm terminal emulator";
    wezterm.default = lib.mkEnableOption "default env";
    ghostty.enable = lib.mkEnableOption "Ghostty";
    ghostty.default = lib.mkEnableOption "default env";

    mpv.enable = lib.mkEnableOption "MPV";
    obs = {
      enable = lib.mkEnableOption "OBS";
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.obs-studio;
      };
    };
    chromium = {
      enable = lib.mkEnableOption "chromium";
    };
    accounting.enable = lib.mkEnableOption "accounting software";
    activity-watch.enable = lib.mkEnableOption "Activity Watch";
    exodus.enable = lib.mkEnableOption "Exodus wallet";
    mangohud.enable = lib.mkEnableOption "MangoHUD";

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "A list of extra packages to install.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.helium.enable {
      home.packages = [
        (pkgs.callPackage ../../../packages/helium.nix { })
      ];
    })
    (lib.mkIf cfg.remmina.enable { home.packages = [ pkgs.remmina ]; })
    (lib.mkIf cfg.lf.enable (import ./lf.nix { inherit pkgs; }))
    (lib.mkIf cfg.zathura.enable (import ./zathura.nix { }))

    (lib.mkIf cfg.foot.enable (import ./foot.nix { inherit pkgs; }))
    (lib.mkIf (cfg.foot.enable && cfg.foot.default) {
      home.sessionVariables.TERMINAL = "foot";
    })
    (lib.mkIf cfg.ghostty.enable (import ./ghostty.nix { inherit pkgs; }))
    (lib.mkIf (cfg.ghostty.enable && cfg.ghostty.default) {
      home.sessionVariables.TERMINAL = "ghostty";
    })
    (lib.mkIf cfg.kitty.enable (import ./kitty.nix { }))
    (lib.mkIf (cfg.kitty.enable && cfg.kitty.default) {
      home.sessionVariables.TERMINAL = "kitty";
    })
    (lib.mkIf cfg.mpv.enable (import ./mpv.nix { inherit pkgs; }))
    (lib.mkIf cfg.wezterm.enable (import ./wezterm.nix { extraConfig = secrets.wezterm-ssh-domains; }))
    (lib.mkIf (cfg.wezterm.enable && cfg.wezterm.default) {
      home.sessionVariables.TERMINAL = "wezterm";
    })

    (lib.mkIf cfg.obs.enable {
      programs.obs-studio = {
        enable = true;
        inherit (cfg.obs) package;
        plugins = with pkgs.obs-studio-plugins; [
          wlrobs
          obs-backgroundremoval
          obs-pipewire-audio-capture
          obs-vaapi # optional AMD hardware acceleration
          obs-gstreamer
          obs-vkcapture
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
        ];
      };
    })
    (lib.mkIf cfg.accounting.enable {
      home.packages = with pkgs; [
        inputs'.paisa.packages.default
        ledger
        beancount
        beancount-language-server
        fava
      ];
    })
    (lib.mkIf cfg.activity-watch.enable {
      home.packages = with pkgs; [
        activitywatch
        aw-watcher-afk
        aw-watcher-window
      ];
    })
    (lib.mkIf cfg.mangohud.enable (import ./mangohud.nix { }))
    (lib.mkIf (cfg.pi.enable || cfg.opencode.enable) {
      home.packages = [ pkgs.agent-browser ];
    })
    (lib.mkIf (cfg.extraPackages != [ ]) { home.packages = cfg.extraPackages; })
    {
      home.activation.agentSkillsConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p $HOME/.agents

        $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
            ${opts.realConfigs}/agents/skills $HOME/.agents/skills
      '';
    }
  ];
}
