{ pkgs, ... }: {
  systemd.services.v2raya = {
    enable = true;
    description = "v2rayA gui client";
    after = [ "network.target" ];
    serviceConfig = {
      Restart = "always";
      ExecStart = "${pkgs.v2raya}/bin/v2rayA";
    };
    path = with pkgs; [ iptables bash ];
    wantedBy = [ "multi-user.target" ];
  };
}
