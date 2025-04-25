{ pkgs, ... }:
{
  # Flameshot is a great screenshot + annotation tool, unfortunately it doens't run
  # natively under Wayland yet, but it does seem to play nicely with xwayland + hyprland :pray:

  home.packages = with pkgs; [
    (flameshot.override {
      # Enable USE_WAYLAND_GRIM compile flag
      enableWlrSupport = true;
    })
  ];

  xdg.configFile."flameshot/flameshot.ini" = {
    text = ''
      [General]
      contrastOpacity=188
      disabledTrayIcon=true
      saveLastRegion=true
      savePath=/home/sleroq/Pictures/Screenshots
      showStartupLaunchMessage=false
      disabledGrimWarning=true
    '';
  };
}
