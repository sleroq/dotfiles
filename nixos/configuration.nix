{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./modules/battery-life.nix

    # ./modules/samba.nix
    ./modules/flatpak.nix
    ./modules/polkit.nix
    ./modules/kwallet.nix
    ./modules/virtualisation.nix
    ./modules/wms/default.nix
    ./modules/apps.nix
    ./modules/sound/default.nix
    ./modules/proxy.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  boot.initrd.systemd.enable = true;
  boot.plymouth.enable = true;
  boot.kernel.sysctl = { "vm.swappiness" = 20; };
  boot.kernelParams = ["quiet"];
  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
  boot.kernelModules = [
    "v4l2loopback" # obs virtual camera
  ];

  # Setup keyfile
  boot.initrd.secrets = {
    "/crypto_keyfile.bin" = null;
  };

  services.fstrim.enable = true;

  boot.initrd.luks.devices."luks-47f43abe-5bff-40e7-9484-5766d62e9b77" = {
    # Enable swap on luks
    device = "/dev/disk/by-uuid/47f43abe-5bff-40e7-9484-5766d62e9b77";
    keyFile = "/crypto_keyfile.bin";
    # Enable trimming
    allowDiscards = true;
  };

  boot.initrd.luks.devices."luks-d8faed41-c117-470b-aa32-b7dd33331e62" = {
    # Enable trimming
    allowDiscards = true;
  };

  networking.hostName = "sleroq-international";
  networking.nameservers = [ "1.1.1.1" "1.1.0.1" ];

  services.journald.extraConfig = ''
      SystemMaxUse=2G
  '';

  networking.wireless.iwd.enable = true;
  # Enable networking
  networking.networkmanager = {
    enable = true;
    wifi.backend = "iwd";
  };

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  hardware.opentabletdriver.enable = true;
  hardware.opentabletdriver.daemon.enable = true;

  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };

  services.nixops-dns.domain = "1.1.1.1";

  # Set your time zone.
  time.timeZone = "Europe/Moscow";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services.flatpak.enable = true;

  # Define a user account
  users.defaultUserShell = pkgs.zsh;
  users.users.sleroq = {
    shell = pkgs.nushell;
    isNormalUser = true;
    description = "sleroq";
    extraGroups = [ "networkmanager" "input" "wheel" "docker" "video" "libvirtd" "adbusers" ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # About fonts - nixos.wiki/wiki/Fonts
  fonts.fontDir.enable = true;
  fonts.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "JetBrainsMono" "FiraCode" "DroidSansMono" "Ubuntu" "Agave" ]; })
    noto-fonts
    noto-fonts-emoji
    noto-fonts-cjk
    roboto
    noto-fonts-extra
    helvetica-neue-lt-std
    arkpandora_ttf
    powerline-fonts
    source-han-sans
    source-han-sans-japanese
    source-han-serif-japanese
    font-awesome
  ];

  # Allow plugdev access to ANNE PRO 2
  # https://github.com/sizezero/dev-notes/blob/master/anne-pro-2.org
  services.udev.extraRules = ''
    SUBSYSTEM=="input", GROUP="input", MODE="0666"
    # For ANNE PRO 2
    SUBSYSTEM=="usb", ATTRS{idVendor}=="04d9", ATTRS{idProduct}=="8008",
    MODE="0666", GROUP="plugdev"
    KERNEL=="hidraw*", ATTRS{idVendor}=="04d9", ATTRS{idProduct}=="8008",
    MODE="0666", GROUP="plugdev"
  '';

  programs.zsh.enable = true;
  environment.shells = with pkgs; [ zsh ];
  environment.pathsToLink = [ "/share/zsh" ];

  nix.settings = {
    substituters = [
      "https://nix-gaming.cachix.org"
      "https://nix-community.cachix.org"
      "https://cache.nixos.org/"
      "https://hyprland.cachix.org"
    ];
    trusted-public-keys = [
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];
  };

  security.pam.loginLimits = [
    { domain = "@users"; item = "rtprio"; type = "-"; value = 1; }
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.11"; # Did you read the comment?

  # Enable flakes:
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
