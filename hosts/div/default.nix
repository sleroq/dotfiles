{
  config,
  inputs,
  lib,
  modulesPath,
  pkgs,
  ...
}:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
    ../../modules/cloudflared.nix
    ../../modules/feishin.nix
    ../../modules/navidrome.nix
    ../../modules/sftpgo.nix
    ../../modules/slusha.nix
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
        4533 # Navidrome music server
        5000 # Private container registry
        8008 # Matrix Tuwunel server
        9100 # Prometheus node exporter metrics
        9882 # Prometheus Podman exporter metrics
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

  sleroq.feishin = {
    enable = true;
    # The Web Audio processing path can be silent even when the browser has
    # successfully fetched the stream. Use the native media element instead.
    webAudio = false;
    cloudflared = {
      tunnel = "music";
      hostname = "feishin.cum.army";
    };
  };

  sleroq.sftpgo = {
    enable = true;
    musicFolder = config.sleroq.navidrome.musicFolder;
    adminEnvironmentFile = config.age.secrets.sftpgoAdminEnv.path;
    usersFile = config.age.secrets.sftpgoUsers.path;
    cloudflared = {
      tunnel = "music";
      hostname = "music-files.cum.army";
    };
  };

  virtualisation = {
    containers.registries.insecure = [ "div.capybara-menkent.ts.net:5000" ];
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
      autoPrune.enable = true;
    };
    oci-containers.backend = "podman";
    oci-containers.containers.prometheus-podman-exporter = {
      image = "quay.io/navidys/prometheus-podman-exporter:v1.21.0";
      autoStart = true;
      ports = [ "0.0.0.0:9882:9882" ];
      volumes = [
        "/run/podman/podman.sock:/run/podman/podman.sock:ro"
      ];
      environment = {
        CONTAINER_HOST = "unix:///run/podman/podman.sock";
      };
      extraOptions = [
        "--security-opt=label=disable"
        "--user=root"
      ];
      cmd = [ "--collector.enable-all" ];
    };
  };

  services.dockerRegistry = {
    enable = true;
    listenAddress = "0.0.0.0";
    enableDelete = true;
    enableGarbageCollect = true;
  };

  # Enable during the final cutover, after the last offline rsync from
  # cumserver has completed. Keeping it disabled makes registry and data
  # staging safe: it cannot start from an incomplete SQLite snapshot.
  sleroq.slusha = {
    enable = true;
    image = "div.capybara-menkent.ts.net:5000/slusha:edge-cumming-beta";
    environmentFile = config.age.secrets.slushaEnv.path;
    cloudflared.tunnel = "music";
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
  age.secrets.sftpgoAdminEnv = {
    owner = "navidrome";
    group = "navidrome";
    file = ./secrets/sftpgoAdminEnv;
  };
  age.secrets.sftpgoUsers = {
    owner = "navidrome";
    group = "navidrome";
    file = ./secrets/sftpgoUsers;
  };
  age.secrets.slushaEnv.file = ../cumserver/secrets/slushaEnv;
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

  nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "sftpgo";

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
