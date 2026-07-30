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
    ../../modules/cloudflared.nix
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
    extraSetFlags = [ "--hostname=div" ];
  };

  services.qemuGuest.enable = true;

  sleroq.cloudflared = {
    enable = true;
    protocol = "http2";
    tunnels.music = {
      id = "fcb39dde-46c0-4819-972c-49867b813bcc";
      credentialsFile = config.age.secrets.cloudflaredDivCredentials.path;
      restartTriggers = [ config.age.secrets.cloudflaredDivCredentials.file ];
    };
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK72BBTnP5Os5ZQfS1BuigNzWMqNFl7lgUH4CJq1bl9P cantundo@pm.me"
  ];

  sleroq.navidrome = {
    enable = true;
    listenAddress = "0.0.0.0";
    cloudflared = {
      tunnel = "music";
      hostname = "music.cum.army";
    };
    environmentFile = config.age.secrets.navidromeEnv.path;
    metrics = {
      enable = true;
      path = "/metrics_itslocalanyway";
    };
  };

  services.matrix-tuwunel = {
    enable = false;
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

  age.secrets.cloudflaredDivCredentials = {
    file = ../../shared/secrets/cloudflared-div.json;
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
