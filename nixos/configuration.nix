# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix # Include the results of the hardware scan.
    ./cachix.nix                 # Community cache
    ./modules/wms/sway.nix
    ./modules/apps.nix
    # ./modules/openvpn.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  # Setup keyfile
  boot.initrd.secrets = {
    "/crypto_keyfile.bin" = null;
  };

  # Enable swap on luks
  boot.initrd.luks.devices."luks-47f43abe-5bff-40e7-9484-5766d62e9b77".device = "/dev/disk/by-uuid/47f43abe-5bff-40e7-9484-5766d62e9b77";
  boot.initrd.luks.devices."luks-47f43abe-5bff-40e7-9484-5766d62e9b77".keyFile = "/crypto_keyfile.bin";

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Moscow";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  services.shadowsocks = {
    enable = true;
    mode = "tcp_and_udp";
    password = "sleroqgay";
    fastOpen = false;
    encryptionMethod = "chacha20-ietf-poly1305";
    extraConfig = {
      nameserver = "8.8.8.8";
      server = ["127.0.0.1"]; # "0.0.0.0"];
      server_port = 8666;
      timeout = 300;
      reuse_port = true;
    };
  };

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

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.xserver.displayManager.sddm.enable = true;

  services.xserver.desktopManager.plasma5 = {
    enable = true;
    excludePackages = with pkgs.libsForQt5; [
      konsole
      elisa
      khelpcenter
      print-manager
      spectacle
    ];
  };

  services.xserver.windowManager.leftwm.enable = true;

  virtualisation.docker.enable = true;

  # Configure keymap in X11
  services.xserver = {
    layout = "us";
    xkbVariant = "";
  };

  # Enable sound with pipewire.
  # sound.enable = true;
  hardware.pulseaudio.enable = false;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;
  
    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;
  services.flatpak.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.defaultUserShell = pkgs.zsh;
  users.users.sleroq = {
    isNormalUser = true;
    description = "sleroq";
    extraGroups = [ "networkmanager" "wheel" "docker" "video" ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

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


  # services.tailscale = {
  #   enable = true;
  # };
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 8666 8667 ];
  networking.firewall.allowedUDPPorts = [ 8666 8667 ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.11"; # Did you read the comment?

  # Enable flakes:
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  security.pki.certificates = [ ''
  -----BEGIN CERTIFICATE-----
MIICNjCCAbwCFDnyCOpczOUFZ4ACPFFHDZELChqCMAoGCCqGSM49BAMCMH8xCzAJ
BgNVBAYTAlVTMRYwFAYDVQQIDA1NZW93IFJlcHVibGljMQ0wCwYDVQQHDARDYXRz
MRkwFwYDVQQKDBBTZXggaW5jb3Jwb3JhdGVkMRkwFwYDVQQLDBBEZXZhYnJhaW4g
aXMgR2F5MRMwEQYDVQQDDApQcml2YXRlIENBMB4XDTIzMDIwNzE3MzI1MVoXDTI0
MDIwNzE3MzI1MVowfzELMAkGA1UEBhMCVVMxFjAUBgNVBAgMDU1lb3cgUmVwdWJs
aWMxDTALBgNVBAcMBENhdHMxGTAXBgNVBAoMEFNleCBpbmNvcnBvcmF0ZWQxGTAX
BgNVBAsMEERldmFicmFpbiBpcyBHYXkxEzARBgNVBAMMClByaXZhdGUgQ0EwdjAQ
BgcqhkjOPQIBBgUrgQQAIgNiAAQNKTJSYn5E2dXPB80hdpYOMf2kqgUEEXYE+QDQ
t6GeSZMxIloPT5Au1b90lk9TjwzdErbuT7a0r77XESI4Trt1WOOVYww+adY3rsPp
DSnL/Zg+FKrg4/fsr9twdAYaVGkwCgYIKoZIzj0EAwIDaAAwZQIwErwbmu1XB2Gx
9KwILBsti3xlKlSCbL8PPtZlItEnM9V//+yxwOT/+LyHdj1q1o1SAjEA3NrOzb9n
sFmi7a5qci9NBeG1c9S1BvZKDTpn6nQe5AlBej09sqvKRetQBWPsIXcL
-----END CERTIFICATE-----
''];
}
