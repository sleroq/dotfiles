{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.myHome.wms.wayland.dwl;
  noctalia = pkgs.callPackage (self + /packages/noctalia-dwl.nix) { };
  storageKey = "${config.xdg.stateHome}/noctalia/storage.key";
  provisionKey = pkgs.writeShellScript "noctalia-storage-key" ''
    if [ ! -f ${lib.escapeShellArg storageKey} ]; then
      umask 077
      ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg (builtins.dirOf storageKey)}
      ${pkgs.coreutils}/bin/od -An -N32 -tx1 /dev/urandom | ${pkgs.coreutils}/bin/tr -d ' \n' > ${lib.escapeShellArg storageKey}
    fi
  '';
  noctaliaConfig = pkgs.runCommand "noctalia-dwl-config.toml" { } ''
    substitute ${self + /home/config/noctalia-dwl/config.toml} "$out" \
      --replace-fail '@storageKey@' ${lib.escapeShellArg storageKey}
    ${lib.getExe noctalia} config validate "$out"
  '';
  sessionUnit = {
    After = [ "graphical-session.target" ];
    PartOf = [ "graphical-session.target" ];
    ConditionEnvironment = "XDG_CURRENT_DESKTOP=dwl";
  };

in
{
  options.myHome.wms.wayland.dwl.enable = lib.mkEnableOption "the minimal DWL desktop";

  config = lib.mkIf cfg.enable {
    home.packages = [
      noctalia
      pkgs.kitty
      pkgs.nemo
      pkgs.nerd-fonts.symbols-only
    ];
    xdg.dataFile."icons/Tela".source = noctalia.trayIcons;
    xdg.configFile."noctalia/config.toml".source = noctaliaConfig;
    xdg.configFile."noctalia/palettes/Rose-Pine-Flat.json".source =
      self + /home/config/noctalia-dwl/Rose-Pine-Flat.json;
    xdg.configFile."systemd/user/app-dwl-obs-.scope.d/timeout.conf".text = ''
      [Scope]
      TimeoutStopSec=15s
    '';

    services.kanshi.settings = [
      {
        profile = {
          name = "desktop";
          outputs = [
            {
              criteria = "DP-1";
              mode = "2560x1440@180Hz";
              position = "0,0";
              scale = 1.0;
            }
          ];
        };
      }
    ];

    systemd.user.services = {
      dwl-kitty = {
        Unit = sessionUnit // {
          Description = "DWL shared Kitty instance";
        };
        Service = {
          ExecStart = "${lib.getExe pkgs.kitty} --single-instance --instance-group dwl --start-as hidden --override remember_window_size=no";
          Restart = "on-failure";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
      dwl-noctalia = {
        Unit = sessionUnit // {
          Description = "DWL native Noctalia shell";
          X-Restart-Triggers = [ noctaliaConfig ];
        };
        Service = {
          ExecStartPre = provisionKey;
          ExecStart = lib.getExe noctalia;
          Restart = "on-failure";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
      cliphist = lib.mkIf config.services.cliphist.enable {
        Unit.ConditionEnvironment = [ "!XDG_CURRENT_DESKTOP=dwl" ];
      };
      cliphist-images =
        lib.mkIf (config.services.cliphist.enable && config.services.cliphist.allowImages)
          {
            Unit.ConditionEnvironment = [ "!XDG_CURRENT_DESKTOP=dwl" ];
          };
      kanshi.Unit.ConditionEnvironment = lib.mkForce [
        "WAYLAND_DISPLAY"
        "XDG_CURRENT_DESKTOP=dwl"
      ];
      caelestia = lib.mkIf config.programs.caelestia.enable {
        Unit.ConditionEnvironment = "XDG_CURRENT_DESKTOP=Hyprland";
      };
    };
  };
}
