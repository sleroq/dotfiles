# This direcotry is meant for configurations relevant on every desktop host

{ pkgs, ... }:
{
  imports = [
    ../../modules/flatpak.nix
    ../../modules/kwallet.nix
    ../../modules/virtualisation.nix
    ../../modules/wms/default.nix
    ../../modules/apps.nix
    ../../modules/sound/default.nix
  ];

  nixpkgs.config.allowUnfree = true;

  networking.nameservers = [ "1.1.1.1" "1.1.0.1" "8.8.8.8" ];
  services.nixops-dns.domain = "1.1.1.1";

  services.fstrim.enable = true;

  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };

  systemd = {
    extraConfig = ''
      DefaultTimeoutStopSec=10s
      DefaultTimeoutStartSec=10s
    '';

    coredump = {
      enable = true;
      extraConfig = "ExternalSizeMax=${toString (8 * 1024 * 1024 * 1024)}";
    };
  };

  services.journald.extraConfig = ''
      SystemMaxUse=2G
  '';

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

  # About fonts - nixos.wiki/wiki/Fonts
  fonts.fontDir.enable = true;
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    nerd-fonts.droid-sans-mono
    nerd-fonts.ubuntu
    nerd-fonts.agave
    # (nerdfonts.override { fonts = [ "JetBrainsMono" "FiraCode" "DroidSansMono" "Ubuntu" "Agave" ]; })
    noto-fonts
    noto-fonts-emoji
    noto-fonts-cjk-sans
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

  environment.shells = with pkgs; [ bash nushell ];
  environment.pathsToLink = [ "/share/bash" "/share/nushell" ];

  services.flatpak.enable = true;

  security.polkit.enable = true;

  security.pam.loginLimits = [
    { domain = "@users"; item = "rtprio"; type = "-"; value = 1; }
  ];

  # Udev rules for Vial keyboard configuration
  # https://get.vial.today/manual/linux-udev.html
  services.udev.extraRules = ''
    # Universal Vial udev rule
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{serial}=="*vial:f64c2b3c*", MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"
  '';

  # Allow plugdev access to ANNE PRO 2
  # https://github.com/sizezero/dev-notes/blob/master/anne-pro-2.org
  # services.udev.extraRules = ''
  #   SUBSYSTEM=="input", GROUP="input", MODE="0666"
  #   # For ANNE PRO 2
  #   SUBSYSTEM=="usb", ATTRS{idVendor}=="04d9", ATTRS{idProduct}=="8008",
  #   MODE="0666", GROUP="plugdev"
  #   KERNEL=="hidraw*", ATTRS{idVendor}=="04d9", ATTRS{idProduct}=="8008",
  #   MODE="0666", GROUP="plugdev"
  # '';

  nix.settings = {
    substituters = [
      "https://nix-gaming.cachix.org"
      "https://nix-community.cachix.org"
      "https://cache.nixos.org/"
      "https://hyprland.cachix.org"

      # From zed flake
      "https://cache.garnix.io"
      "https://zed.cachix.org"
    ];
    trusted-public-keys = [
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="

      # From zed flake
      "zed.cachix.org-1:/pHQ6dpMsAZk2DiP4WCL0p9YDNKWj2Q5FL20bNmw1cU="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
  };

  # Enable flakes:
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
