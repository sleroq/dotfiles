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
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

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
    metrics = {
      enable = true;
      path = "/metrics_itslocalanyway";
    };
  };

  age.secrets.cloudflaredToken = {
    file = ../../shared/secrets/cloudflared.key;
  };
  systemd.services.cloudflared-navidrome.restartTriggers = [
    config.age.secrets.cloudflaredToken.file
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
  };

  system.stateVersion = "26.05";
}
