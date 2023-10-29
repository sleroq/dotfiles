# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix # Include the results of the hardware scan.
    ./cachix.nix # Community cache

    # ./modules/virtualisation.nix
    ./modules/wms/default.nix
    ./modules/apps.nix
    ./modules/flatpak-workaround.nix
    ./modules/sound/default.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

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

  # Battery life
  services.power-profiles-daemon.enable = false;
  services.thermald.enable = true;

  services.tlp = {
    enable = true;
    settings = {
      RUNTIME_PM_ON_AC="auto";
      RUNTIME_PM_ON_BAT="auto";
      CPU_ENERGY_PERF_POLICY_ON_AC="balance_power";
      CPU_ENERGY_PERF_POLICY_ON_BAT="balance_power";
    };
  };

  # Enable touchpad support (enabled default in most desktopManager)
  # services.xserver.libinput.enable = true;
  services.flatpak.enable = true;

  # Define a user account
  users.defaultUserShell = pkgs.zsh;
  users.users.sleroq = {
    isNormalUser = true;
    description = "sleroq";
    extraGroups = [ "networkmanager" "input" "wheel" "docker" "video" "libvirtd" "adbusers" ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.nvidia.acceptLicense = true; # Why do I need this? I don't even have nvidia


  # About fonts - nixos.wiki/wiki/Fonts
  fonts.fontDir.enable = true;
  fonts.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "JetBrainsMono" "FiraCode" "DroidSansMono" ]; })
  ];

  programs.zsh.enable = true;
  environment.shells = with pkgs; [ zsh ];
  environment.pathsToLink = [ "/share/zsh" ];

  nix.settings = {
    substituters = [
      "https://nix-gaming.cachix.org"
      "https://nix-community.cachix.org"
      "https://cache.nixos.org/"
    ];
    trusted-public-keys = [
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };


  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    25565 # Minecraft
  ];


  # About polkit - https://nixos.wiki/wiki/Polkit
  security.polkit.enable = true;

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
