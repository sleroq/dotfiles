{
  config,
  inputs,
  modulesPath,
  pkgs,
  ...
}:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
    ../../modules/navidrome.nix
    ../../modules/tuwunel.nix
  ];

  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;
  };
  boot.loader.efi.canTouchEfiVariables = false;
  boot.tmp.cleanOnBoot = true;

  networking = {
    hostName = "div";
    useDHCP = true;
    firewall = {
      enable = true;
      interfaces.tailscale0.allowedTCPPorts = [
        4533
        8008
        9100
      ];
    };
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 4096;
    }
  ];

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      AuthorizedKeysFile = ".ssh/authorized_keys /etc/ssh/authorized_keys.d/%u";
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
      X11Forwarding = false;
    };
  };

  services.journald.extraConfig = ''
    SystemMaxUse=500M
  '';

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };

  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  services.qemuGuest.enable = true;

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK72BBTnP5Os5ZQfS1BuigNzWMqNFl7lgUH4CJq1bl9P cantundo@pm.me"
  ];

  services.navidrome = {
    enable = true;
    listenAddress = "0.0.0.0";
    cloudflared.tokenFile = config.age.secrets.cloudflaredToken.path;
    environmentFile = config.age.secrets.navidromeEnv.path;
    metrics = {
      enable = true;
      path = "/metrics_itslocalanyway";
    };
  };

  services.matrix-tuwunel = {
    enable = true;
    # Keep the current server version for the data migration. Upgrade only
    # after the migrated database has been verified on div.
    package = inputs.nixpkgs-cumserver.legacyPackages.x86_64-linux.matrix-tuwunel;
    listenAddress = "0.0.0.0";
    registrationTokenFile = config.age.secrets.tuwunelRegistrationToken.path;
    turn = {
      enable = true;
      secretFile = config.age.secrets.tuwunelTurnSecret.path;
    };
    elementCallUrl = "https://call.cum.army";
  };

  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "0.0.0.0";
    openFirewall = false;
    enabledCollectors = [
      "systemd"
      "processes"
    ];
  };

  age.secrets.cloudflaredToken = {
    file = ../../shared/secrets/cloudflared.key;
  };
  age.secrets.navidromeEnv = {
    owner = "navidrome";
    group = "navidrome";
    file = ./secrets/navidromeEnv;
  };
  age.secrets.tuwunelRegistrationToken = {
    file = ./secrets/tuwunelRegistrationToken;
  };
  age.secrets.tuwunelTurnSecret = {
    file = ./secrets/tuwunelTurnSecret;
  };
  systemd.services.cloudflared-navidrome.restartTriggers = [
    config.age.secrets.cloudflaredToken.file
  ];
  systemd.services.navidrome.restartTriggers = [
    config.age.secrets.navidromeEnv.file
  ];
  systemd.services.tuwunel.restartTriggers = [
    config.age.secrets.tuwunelRegistrationToken.file
    config.age.secrets.tuwunelTurnSecret.file
  ];

  environment.systemPackages = with pkgs; [
    curl
    git
    btop
    dust
    python3
    tmux
    vim
  ];

  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    optimise.automatic = true;

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
  systemd.oomd.enableUserSlices = true;

  system.stateVersion = "26.05";
}
