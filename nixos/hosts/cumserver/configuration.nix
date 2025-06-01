{
  modulesPath,
  lib,
  pkgs,
  secrets,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
  ];
  boot.loader.grub.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
    };
  };

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
