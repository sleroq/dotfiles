{
  lib,
  pkgs,
  secrets,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./applications.nix
    ./backups.nix
  ];

  boot = {
    loader.grub = {
      enable = true;
      device = "/dev/sda";
      configurationLimit = 10;
    };
    kernelParams = [
      "console=tty0"
      "console=ttyS0,115200n8"
    ];
    growPartition = true;
    blacklistedKernelModules = [ "algif_aead" ];
    extraModprobeConfig = ''
      install esp4 ${pkgs.coreutils}/bin/false
      install esp6 ${pkgs.coreutils}/bin/false
      install rxrpc ${pkgs.coreutils}/bin/false
    '';
    kernel.sysctl = {
      "kernel.yama.ptrace_scope" = 2;
      "net.mptcp.enabled" = 0;
    };
    tmp.cleanOnBoot = true;
  };

  networking = {
    hostName = "roundy";
    useNetworkd = true;
    useDHCP = false;
    interfaces.ens3.useDHCP = true;
    nftables.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [
        22
        80
        443
      ];
      extraInputRules = ''
        ip saddr ${secrets.cumserverAddress} tcp dport { 9100, 9599 } accept
        ip saddr { ${lib.concatStringsSep ", " secrets.zabbixServers} } tcp dport 10050 accept
      '';
    };
  };

  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";
  swapDevices = [
    {
      device = "/swapfile";
      size = 2048;
    }
  ];

  services = {
    qemuGuest.enable = true;
    openssh = {
      enable = true;
      openFirewall = false;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "prohibit-password";
        X11Forwarding = false;
        AllowUsers = [ "root" ];
      };
    };
    prometheus.exporters.node = {
      enable = true;
      listenAddress = "0.0.0.0";
      openFirewall = false;
      enabledCollectors = [
        "systemd"
        "processes"
      ];
    };
    # Preserve the provider's native agent; do not run its shell installer.
    zabbixAgent = {
      enable = true;
      server = lib.concatStringsSep "," secrets.zabbixServers;
      listen.port = 10050;
      openFirewall = false;
      settings = {
        StartAgents = 3;
        DebugLevel = 3;
        Timeout = 30;
        DenyKey = "system.run[*]";
        UserParameter = "timeweb_config_version,echo 127";
      };
    };
    journald.extraConfig = ''
      SystemMaxUse=200M
      MaxRetentionSec=30day
    '';
  };

  systemd.tmpfiles.rules = [ "e /tmp 1777 root root 7d" ];

  # Leave mutableUsers and the existing root console password unchanged.
  users.users.root.openssh.authorizedKeys.keys = secrets.authorizedKeys;

  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    curl
    git
    htop
    jq
    python3
    rsync
    openssh
    nixos-rebuild
  ];
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    max-jobs = 0;
    builders = lib.mkForce "";
  };
  # GC is operator-controlled; no automatic generation or store deletion.
  nix.gc.automatic = false;

  # Installation compatibility version, not the nixpkgs release.
  system.stateVersion = "25.11";
}
