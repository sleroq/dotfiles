{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.sleroq.wms.dwl;
  session = pkgs.writeTextFile {
    name = "dwl-uwsm-session";
    destination = "/share/wayland-sessions/dwl-uwsm.desktop";
    text = ''
      [Desktop Entry]
      Name=DWL (UWSM)
      Comment=Minimal grouped Wayland desktop
      Exec=${lib.getExe config.programs.uwsm.package} start -F dwl.desktop
      Type=Application
      DesktopNames=dwl
    '';
    derivationArgs.passthru.providedSessions = [ "dwl-uwsm" ];
  };
in
{
  options.sleroq.wms.dwl.enable = lib.mkEnableOption "the DWL desktop alternative";

  config = lib.mkIf cfg.enable {
    programs.dwl.package = pkgs.callPackage ../../packages/dwl { src = inputs.dwl; };
    programs.uwsm.enable = true;
    environment.systemPackages = [ config.programs.dwl.package ];
    services.displayManager.sessionPackages = [ session ];
    security.pam.services.swaylock = { };

    xdg.portal = {
      wlr = {
        enable = true;
        settings.screencast = {
          chooser_type = "dmenu";
          chooser_cmd = "${lib.getExe pkgs.tofi} --prompt-text='Share screen or window: '";
        };
      };
      config.dwl = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
      };
    };

    environment.etc."xdg/uwsm/env-dwl".text = ''
      export QT_AUTO_SCREEN_SCALE_FACTOR=1
      export QT_QPA_PLATFORM='wayland;xcb'
      export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
      export QT_QPA_PLATFORMTHEME=gtk
      export NIXOS_OZONE_WL=1
      export _JAVA_AWT_WM_NONREPARENTING=1
    '';
  };
}
