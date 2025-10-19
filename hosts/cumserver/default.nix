{
  modulesPath,
  lib,
  pkgs,
  secrets,
  config,
  inputs',
  ...
}:
let
  serviceWrapper = import ./modules/telegram-bot.nix { inherit config lib pkgs; };
  
  bayan = serviceWrapper.mkTelegramBot {
    name = "bayan";
    package = inputs'.bayan.packages.default;
    secretFile = ./secrets/bayanEnv;
    dataDir = "/var/lib/bayan";
  };
  
  kopoka = serviceWrapper.mkTelegramBot {
    name = "kopoka";
    package = inputs'.kopoka.packages.default;
    secretFile = ./secrets/kopokaEnv;
  };
  
  spoiler-images = serviceWrapper.mkTelegramBot {
    name = "spoiler-images";
    package = inputs'.spoiler-images.packages.default;
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
    ./modules/zipline.nix
    ./modules/radicale.nix
    ./modules/monitoring
    ./modules/bore.nix
    ./modules/podman.nix
    ./modules/broadcast-box.nix
    ./modules/oven-media-engine.nix
    ./modules/tuwunel.nix
    ./modules/marzban.nix
    ./modules/traggo.nix
    ./modules/slusha.nix
    ./modules/n8n.nix
    ./modules/minecraft.nix
    bayan
    kopoka
    spoiler-images
  ];
  facter.reportPath = ./facter.json;

  boot.loader.grub.enable = true;
  boot.tmp.cleanOnBoot = true;

  swapDevices = [
    { device = "/swapfile"; size = 8192; }
  ];

  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
  };

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
  cumserver.tuwunel = {
    enable = true;
    package = inputs'.tuwunel.packages.default;
  };

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
  age.secrets.nodeExporter3Password = {
    owner = "prometheus";
    group = "prometheus";
    file = ./secrets/nodeExporter3Password;
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
        name = "Dokploy";
        address = "${secrets.dokployServerIP}:9100";
        passwordPath = config.age.secrets.nodeExporter3Password.path;
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

  age.secrets.ziplineEnv = {
    owner = "zipline";
    group = "zipline";
    file = ./secrets/ziplineEnv;
  };

  cumserver.zipline = {
    enable = true;
    environmentFile = config.age.secrets.ziplineEnv.path;
  };
  
  # cumserver.broadcast-box = {
  #   enable = true;
  #   # image = "localhost/meow:latest";
  #   domain = "web.cum.army";
  #   # profiles.enable = true;
  #   # profiles.streamProfiles = {
  #   #   "saygex2_1b2e45eb-360c-4d75-a29f-0ecff7e88762" = {
  #   #     streamKey = "saygex2";
  #   #     isPublic = true;
  #   #     motd = "Welcome to my stream!";
  #   #   };
  #   # };
  # };

  # cumserver.n8n.enable = true;

  cumserver.minecraft.cum.enable = true;
  # cumserver.minecraft.forever-chu.enable = true;

  cumserver.oven-media-engine = {
    enable = true;
    domain = "web.cum.army";

    videoBypass = true;
    videoCodec = "h264";
    videoWidth = 1920;
    videoHeight = 1080;
    videoBitrate = 5000000;

    # WebRTC optimizations  
    webrtcRtx = true;
    webrtcJitterBuffer = true;
    webrtcUlpfec = true;
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
  # services.zefxi = {
  #   enable = false;
  #   caddy.enable = true;
  #   environmentFile = config.age.secrets.zefxiEnv.path;
  # };

  age.secrets.sieveEnv = {
    owner = "sieve";
    group = "sieve";
    file = ./secrets/sieveEnv;
  };
  services.sieve = {
    enable = true;
    environmentFile = config.age.secrets.sieveEnv.path;
  };

  age.secrets.slushaEnv = {
    owner = "slusha";
    group = "slusha";
    file = ./secrets/slushaEnv;
  };
  age.secrets.slushaConfig = {
    owner = "slusha";
    group = "slusha";
    mode = "0644";
    file = ./secrets/slushaConfig.js;
  };
  cumserver.slusha = {
    enable = true;
    image = "localhost/slusha:latest";
    environmentFile = config.age.secrets.slushaEnv.path;
    configFile = config.age.secrets.slushaConfig.path;
  };

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "minecraft-server"
    "sieve"
  ];

  environment.systemPackages = map lib.lowPrio [
    pkgs.curl
    pkgs.gitMinimal
    pkgs.fastfetch
    pkgs.btop
    pkgs.neovim
    pkgs.wget
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

  users.users.root.hashedPassword = "$6$vsKWQuT3n7JRBP.s$uI.Pyq.dN/kxLqmGF9Pl/yuVGRp/9Y6sQXVNqAsNm4impBdDgAnazM1VVu9jZ4oHfZRsFCXvZTIwvXWoSF76x.";

  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "24.05";
}
