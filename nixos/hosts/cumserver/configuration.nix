{
  modulesPath,
  lib,
  pkgs,
  secrets,
  config,
  inputs,
  ...
}:
let
  serviceWrapper = import ./modules/telegram-bot.nix { inherit config lib pkgs; };
  
  bayan = serviceWrapper.mkTelegramBot {
    name = "bayan";
    package = inputs.bayan.packages.${pkgs.system}.default;
    secretFile = ./secrets/bayanEnv;
    dataDir = "/var/lib/bayan";
  };
  
  kopoka = serviceWrapper.mkTelegramBot {
    name = "kopoka";
    package = inputs.kopoka.packages.${pkgs.system}.default;
    secretFile = ./secrets/kopokaEnv;
  };
  
  spoiler-images = serviceWrapper.mkTelegramBot {
    name = "spoiler-images";
    package = inputs.spoiler-images.packages.${pkgs.system}.default;
    secretFile = ./secrets/spoilerImagesEnv;
  };
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
    ./modules/caddy.nix
    ./modules/matterbridge.nix
    ./modules/mailserver.nix
    ./modules/navidrome.nix
    ./modules/radicale.nix
    ./modules/monitoring
    ./modules/bore.nix
    ./modules/podman.nix
    ./modules/broadcast-box.nix
    ./modules/tuwunel.nix
    ./modules/marzban.nix
    ./modules/traggo.nix
    bayan
    kopoka
    spoiler-images
  ];
  boot.loader.grub.enable = true;
  boot.tmp.cleanOnBoot = true;

  services.logrotate.enable = true;
  services.fail2ban.enable = true;
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
    };
  };

  services.qemuGuest.enable = true;

  cumserver.caddy.enable = true;
  cumserver.matterbridge.enable = true;
  cumserver.mailserver.enable = true;
  cumserver.radicale.enable = true;
  cumserver.bore.enable = false;
  cumserver.podman.enable = true;
  cumserver.tuwunel.enable = true;

  age.secrets.marzbanMetricsEnv = {
    owner = "root";
    group = "root";
    file = ./secrets/marzbanMetricsEnv;
  };
  cumserver.marzban = {
    enable = true;
    metricsEnvironmentFile = config.age.secrets.marzbanMetricsEnv.path;
  };

  cumserver.traggo.enable = true;

  age.secrets.grafanaPassword = { owner = "grafana";
      group = "grafana";
      file = ./secrets/grafanaPassword;
  };
  age.secrets.nodeExporter1Password = {
    owner = "prometheus";
    group = "prometheus";
    file = ./secrets/nodeExporter1Password;
  };
  age.secrets.nodeExporter2Password = {
    owner = "prometheus";
    group = "prometheus";
    file = ./secrets/nodeExporter2Password;
  };
  cumserver.monitoring = {
    enable = true;
    grafanaPasswordPath = config.age.secrets.grafanaPassword.path;
    localNodeName = "Germany";
    remoteNodes = [
      {
        name = "Poland";
        address = "${secrets.marzbanNode1IP}:9100";
        passwordPath = config.age.secrets.nodeExporter1Password.path;
        enableTLS = true;
        tlsInsecure = true;
      }
      {
        name = "Moscow";
        address = "${secrets.marzbanNode2IP}:9100";
        passwordPath = config.age.secrets.nodeExporter2Password.path;
        enableTLS = true;
        tlsInsecure = true;
      }
    ];
  };

  cumserver.navidrome = {
    enable = true;
    filebrowser.enable = true;
    feishin.enable = true;
  };
  
  cumserver.broadcast-box = {
    enable = true;
    domain = "web.cum.army";
    extraEnvironment = {
      DISABLE_STATUS = "false";
    };
  };

  services.bayan.enable = true;
  services.kopoka.enable = true;
  services.spoiler-images.enable = true;

  age.secrets.reactorEnv = {
    owner = "reactor";
    group = "reactor";
    file = ./secrets/reactorEnv;
  };
  services.reactor = {
    enable = true;
    environmentFile = config.age.secrets.reactorEnv.path;
  };

  # age.secrets.zefxiEnv = {
  #   owner = "zefxi";
  #   group = "zefxi";
  #   file = ./secrets/zefxiEnv;
  # };
  services.zefxi = {
    enable = false;
    caddy.enable = true;
    environmentFile = config.age.secrets.zefxiEnv.path;
  };

  age.secrets.sieveEnv = {
    owner = "sieve";
    group = "sieve";
    file = ./secrets/sieveEnv;
  };
  services.sieve = {
    enable = true;
    environmentFile = config.age.secrets.sieveEnv.path;
  };

  # age.secrets.slushaEnv = {
  #   owner = "slusha";
  #   group = "slusha";
  #   file = ./secrets/slushaEnv;
  # };
  # age.secrets.slushaConfig = {
  #   owner = "slusha";
  #   group = "slusha";
  #   file = ./secrets/slushaConfig.js;
  # };
  services.slusha = {
    enable = false;
    environmentFile = config.age.secrets.slushaEnv.path;
    configFile = config.age.secrets.slushaConfig.path;
  };

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "sieve"
  ];

  environment.systemPackages = map lib.lowPrio [
    pkgs.curl
    pkgs.gitMinimal
    pkgs.fastfetch
    pkgs.btop
  ];

  networking = {
    hostName = "cumserver";
    useDHCP = false;
    dhcpcd.enable = false;

    interfaces.ens3 = {
      ipv4 = {
        routes = [
          {
            address = "172.16.0.1";
            prefixLength = 32;
          }
        ];
        addresses = [
          {
            address = secrets.ipv4;
            prefixLength = 32;
          }
        ];
      };
      
      ipv6.addresses = [
        {
          address = secrets.ipv6;
          prefixLength = 64;
        }
      ];
    };

    defaultGateway = {
      address = "172.16.0.1";
      interface = "ens3";
    };

    defaultGateway6 = {
      address = "2a0d:d940:11:3f8::1";
      interface = "ens3";
    };

    nameservers = [
      "1.1.1.1"
      "1.0.0.1"
      "2606:4700:4700::1111"
      "2606:4700:4700::1001"
    ];
  };

  services.resolved.enable = true;

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK72BBTnP5Os5ZQfS1BuigNzWMqNFl7lgUH4CJq1bl9P cantundo@pm.me"
  ];

  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };

  system.stateVersion = "24.05";
}
