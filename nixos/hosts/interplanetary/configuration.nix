{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ../../modules/flatpak.nix
    ../../modules/kwallet.nix
    ../../modules/virtualisation.nix
    ../../modules/wms/default.nix
    ../../modules/apps.nix
    ../../modules/sound/default.nix
    # ../../modules/proxy.nix
  ];

  hardware.amdgpu.initrd.enable = true;

  # Bootloader.
  boot = {
    kernelPackages = pkgs.linuxKernel.packages.linux_zen;
    tmp.cleanOnBoot = true;

    plymouth = {
      enable = true;
      theme = "rings";
      themePackages = with pkgs; [
        # By default we would install all themes
        (adi1090x-plymouth-themes.override {
          selected_themes = [ "rings" ];
        })
      ];
    };

    # Enable "Silent Boot"
    consoleLogLevel = 0;
    initrd = {
      systemd.enable = true;
      verbose = false;
      luks.devices."luks-16e9a143-3440-4844-9742-9fb6f3a2f679" = {
        device = "/dev/disk/by-uuid/16e9a143-3440-4844-9742-9fb6f3a2f679";
        allowDiscards = true;
      };
    };
    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];

    kernel.sysctl = { "vm.swappiness" = 10; };
    extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
    kernelModules = [
      "v4l2loopback" # obs virtual camera
    ];

    # Hide the OS choice for bootloaders.
    # It's still possible to open the bootloader list by pressing any key
    # It will just not appear on screen unless a key is pressed
    loader.timeout = 0;
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
  };

  services.logind.extraConfig = ''
    # don’t shutdown when power button is short-pressed
    HandlePowerKey=ignore
  '';

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

  environment.variables = {
    # https://wiki.archlinux.org/title/Hardware_video_acceleration#Configuring_Vulkan_Video
    RADV_PERFTEST = "video_decode,video_encode";
  };

  services.fstrim.enable = true;

  networking.hostName = "sleroq-interplanetary";
  networking.nameservers = [ "1.1.1.1" "1.1.0.1" ];

  networking.networkmanager.enable = true;

  services.journald.extraConfig = ''
      SystemMaxUse=2G
  '';

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
  users.defaultUserShell = pkgs.bash;
  users.users.sleroq = {
    shell = pkgs.nushell;
    isNormalUser = true;
    description = "sleroq";
    extraGroups = [ "networkmanager" "input" "wheel" "video" "libvirtd" "adbusers" "uinput" ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

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

  environment.shells = with pkgs; [ bash nushell ];
  environment.pathsToLink = [ "/share/bash" "/share/nushell" ];

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
  system.stateVersion = "24.11"; # Did you read the comment?

  security.polkit.enable = true;

  # Enable flakes:
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
