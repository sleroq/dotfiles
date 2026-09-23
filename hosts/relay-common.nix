{
  lib,
  modulesPath,
  pkgs,
  ...
}:

{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot = {
    kernelModules = [ "tcp_bbr" ];
    loader.grub.enable = true;
    kernel.sysctl = {
      "net.core.default_qdisc" = "fq";
      "net.core.somaxconn" = 8192;
      "net.ipv4.ip_forward" = 0;
      "net.ipv4.tcp_congestion_control" = "bbr";
      "net.ipv4.tcp_max_syn_backlog" = 8192;
      "net.ipv4.tcp_keepalive_time" = 300;
    };
  };

  networking = {
    enableIPv6 = false;
    useDHCP = lib.mkDefault true;
    nftables.enable = true;
    firewall.enable = true;
  };

  services = {
    prometheus.exporters.node = {
      enable = true;
      listenAddress = "0.0.0.0";
      enabledCollectors = [
        "systemd"
        "processes"
      ];
    };
    journald.extraConfig = ''
      SystemMaxUse=100M
    '';
    openssh = {
      enable = true;
      openFirewall = false;
      settings = {
        AllowUsers = [ "root" ];
        KbdInteractiveAuthentication = false;
        LoginGraceTime = 30;
        MaxAuthTries = 6;
        PasswordAuthentication = false;
        PermitRootLogin = "prohibit-password";
        X11Forwarding = false;
      };
    };
    qemuGuest.enable = true;
  };

  users.users.root.hashedPassword = "!";

  environment.systemPackages = with pkgs; [
    curl
    tcpdump
  ];

  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      max-jobs = 1;
    };
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
    };
  };

  zramSwap = {
    enable = true;
    algorithm = "lz4";
  };
  systemd.oomd.enableSystemSlice = true;

  system.stateVersion = "26.05";
}
