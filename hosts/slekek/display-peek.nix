{
  config,
  lib,
  pkgs,
  ...
}:
let
  btopConfig = pkgs.writeText "slekek-btop.conf" ''
    color_theme = "${pkgs.btop}/share/btop/themes/tokyo-night.theme"
    theme_background = false
    truecolor = true
    tty_mode = false
    rounded_corners = true
    graph_symbol = "braille"
    shown_boxes = "cpu mem net"
    update_ms = 500
    show_cpu_freq = true
    show_coretemp = true
    show_battery = true
    mem_graphs = true
    show_disks = true
    net_auto = true
    net_sync = true
  '';

  btopWrapper = pkgs.writeShellScript "slekek-btop-run" ''
    export TERM="xterm-256color"
    export COLORTERM="truecolor"
    export LANG="en_US.UTF-8"
    export HOME="/run/slekek-btop"
    ${pkgs.coreutils}/bin/chown 65534:65534 /run/slekek-btop
    exec ${pkgs.util-linux}/bin/setpriv --reuid=65534 --regid=65534 --clear-groups \
      ${pkgs.btop}/bin/btop --config ${btopConfig} --force-utf
  '';

  peekDaemon = pkgs.writers.writePython3 "slekek-display-peek" { } ''
    import glob
    import os
    import select
    import struct
    import subprocess
    import time

    WAKE_DEVICES = {
        "FTS3528:00 2808:1015",
        "Power Button",
        "Steam Deck",
    }
    INPUT_EVENT = struct.Struct("llHHi")
    EV_KEY = 1
    KEY_POWER = 116
    WAKE_SECONDS = 60.0
    WAKE_BRIGHTNESS = "20000"
    POWER_DEBOUNCE_SECONDS = 0.4
    SYSTEMCTL = (
        "${pkgs.systemd}"
        "/bin/systemctl"
    )


    def write_sysfs(pattern, value):
        for path in glob.glob(pattern):
            try:
                with open(path, "w", encoding="ascii") as handle:
                    handle.write(value)
            except OSError:
                pass


    def open_input_fds():
        fds = []
        for name_path in sorted(glob.glob("/sys/class/input/event*/device/name")):
            try:
                with open(name_path, encoding="utf-8") as handle:
                    name = handle.read().strip()
            except OSError:
                continue
            if name not in WAKE_DEVICES:
                continue
            event_dir = os.path.dirname(os.path.dirname(name_path))
            event_name = os.path.basename(event_dir)
            dev_path = f"/dev/input/{event_name}"
            try:
                flags = os.O_RDONLY | os.O_NONBLOCK
                fds.append(os.open(dev_path, flags))
            except OSError:
                continue
        return fds


    def sleep_display():
        subprocess.run([SYSTEMCTL, "stop", "slekek-btop.service"], check=False)
        write_sysfs("/sys/class/graphics/fb*/blank", "4")
        write_sysfs("/sys/class/backlight/*/brightness", "0")
        write_sysfs("/sys/class/backlight/*/bl_power", "4")


    def wake_display():
        write_sysfs("/sys/class/graphics/fb*/blank", "0")
        write_sysfs("/sys/class/backlight/*/bl_power", "0")
        write_sysfs("/sys/class/backlight/*/brightness", WAKE_BRIGHTNESS)
        try:
            with open("/dev/tty1", "w", encoding="ascii") as tty:
                tty.write("\033[9;0]")
        except OSError:
            pass
        subprocess.run([SYSTEMCTL, "start", "slekek-btop.service"], check=False)


    def read_key_downs(fd):
        keys = []
        try:
            data = os.read(fd, INPUT_EVENT.size * 32)
        except BlockingIOError:
            return keys
        limit = len(data) - INPUT_EVENT.size + 1
        for offset in range(0, limit, INPUT_EVENT.size):
            _, _, ev_type, code, value = INPUT_EVENT.unpack_from(data, offset)
            if ev_type == EV_KEY and value == 1:
                keys.append(code)
        return keys


    def main():
        sleep_display()
        fds = open_input_fds()
        awake = False
        deadline = 0.0
        last_power = 0.0

        while True:
            timeout = max(0.0, deadline - time.monotonic()) if awake else None
            ready, _, _ = select.select(fds, [], [], timeout)

            if not ready:
                sleep_display()
                awake = False
                continue

            now = time.monotonic()
            for fd in ready:
                for code in read_key_downs(fd):
                    if code == KEY_POWER:
                        if now - last_power < POWER_DEBOUNCE_SECONDS:
                            continue
                        last_power = now
                        if awake:
                            sleep_display()
                            awake = False
                            continue
                    if not awake:
                        wake_display()
                        awake = True
                    deadline = now + WAKE_SECONDS


    main()
  '';
in
{
  config = lib.mkIf config.slekek.serverMode {
    boot.kernelParams = [ "consoleblank=0" ];

    fonts = {
      fontconfig.enable = true;
      packages = with pkgs; [
        jetbrains-mono
        dejavu_fonts
      ];
    };

    services.logind.settings.Login = {
      HandlePowerKey = "ignore";
      HandlePowerKeyLongPress = "poweroff";
    };

    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="backlight", ATTR{brightness}="0", ATTR{bl_power}="4"
    '';

    systemd.services = {
      "systemd-backlight@".enable = false;
      "getty@tty1".enable = false;
      "autovt@tty1".enable = false;

      slekek-btop = {
        description = "Read-only TrueColor btop status display on tty1 via kmscon";
        conflicts = [
          "getty@tty1.service"
          "autovt@tty1.service"
        ];
        serviceConfig = {
          ExecStart = lib.concatStringsSep " " [
            "${pkgs.kmscon}/bin/kmscon"
            "--vt tty1"
            "--switchvt"
            "--no-libseat"
            "--drm"
            "--no-hwaccel"
            "--screen right"
            "--no-issue"
            "--no-mouse"
            "--no-blink"
            "--dpms-timeout 0"
            "--font-engine pango"
            "--font-name=\"JetBrains Mono\""
            "--font-size 16"
            "--term xterm-256color"
            "--oneshot"
            "--login --"
            btopWrapper
          ];
          RuntimeDirectory = "slekek-btop";
          KillMode = "mixed";
        };
      };

      slekek-display-peek = {
        description = "Wake Steam Deck display with btop on touch or button press";
        wantedBy = [ "multi-user.target" ];
        after = [ "systemd-udev-settle.service" ];
        serviceConfig = {
          ExecStart = peekDaemon;
          Restart = "always";
          RestartSec = 2;
        };
      };
    };
  };
}
