{ pkgs,... }: {
  systemd.services.lemurs = {
    after = [
      "systemd-user-sessions.service"
      "plymouth-quit-wait.service"
      "getty@tty2.service"
    ];
    environment = {
      RUST_LOG = "Trace";
      PWD = "/var/lib/lemurs";
    };
    serviceConfig = {
      ExecStart = "${pkgs.lemurs}/bin/lemurs";
      WorkingDirectory = "/var/lib/lemurs";
      StandardInput = "tty";
      TTYPath = "/dev/tty2";
      TTYReset = "yes";
      TTYVHangup = "yes";
      Type = "idle";
    };
    aliases = [ "display-manager.service" ];
  };
  systemd.tmpfiles.rules = [
    "d /var/lib/lemurs 0755 root root"
  ];

  environment.systemPackages = with pkgs; [
    lemurs
  ];
}
