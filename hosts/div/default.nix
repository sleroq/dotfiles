{
  config,
  modulesPath,
  pkgs,
  ...
}:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
    ../../modules/navidrome.nix
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
    firewall.enable = true;
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
    cloudflared.tokenFile = config.age.secrets.cloudflaredToken.path;
    environmentFile = config.age.secrets.navidromeEnv.path;
    metrics = {
      enable = true;
      path = "/metrics_itslocalanyway";
    };
  };

  age.secrets.cloudflaredToken = {
    file = ../../shared/secrets/cloudflared.key;
  };
  age.secrets.navidromeEnv = {
    owner = "navidrome";
    group = "navidrome";
    file = ./secrets/navidromeEnv;
  };
  systemd.services.cloudflared-navidrome.restartTriggers = [
    config.age.secrets.cloudflaredToken.file
  ];
  systemd.services.navidrome.restartTriggers = [
    config.age.secrets.navidromeEnv.file
  ];

  environment.systemPackages = with pkgs; [
    curl
    git
    htop
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
