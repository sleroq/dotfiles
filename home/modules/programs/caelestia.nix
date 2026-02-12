_: {
  programs.caelestia = {
    enable = true;
    systemd = {
      enable = true;
      target = "graphical-session.target";
    };
    settings = {
      general.idle.timeouts = [
        {
          timeout = 600000;
          idleAction = "lock";
        }
        {
          timeout = 800000;
          idleActon = "dpms off";
          returnAction = "dpms on";
        }
        {
          timeout = 120000;
          idleAction = ["systemctl" "suspend-then-hibernate"];
        }
      ];
      services = {
        weatherLocation = "43.25654,76.92848";
        useFahrenheit = false;
      };
      bar.status = {
        showBattery = false;
      };
      paths.wallpaperDir = "~/Pictures/wallpapers";
      utilities.toasts.kbLayoutChanged = false;
    };
    cli = {
      enable = true;
    };
  };
}
