# This direcotry is meant for configurations relevant on every desktop host

{ pkgs, config, secrets, ... }:
{
  imports = [
    ../modules/flatpak.nix
    ../modules/virtualisation.nix
    ../modules/wms/default.nix
    ../modules/apps.nix
    ../modules/sound/default.nix
    ../modules/sing-box.nix
    ../modules/openvpn-work-vpn.nix
    ../modules/kwallet.nix
    ../modules/webdav.nix
    ../modules/tailscale.nix
  ];

  programs.ssh.startAgent = true;

  environment.systemPackages = [
    pkgs.git-crypt # Required to build this nix repo...
  ];

  # Fixes for low memory situations:
  zramSwap = {
    enable = true;
    algorithm = "lz4"; # Bad compression but fast
  };
  systemd.oomd.enableUserSlices = true;  # take action on user-space process hierarchies

  # If other stuff doesn't help:
  # services.earlyoom = {
  #     enable = true;
  #     freeSwapThreshold = 2;
  #     freeMemThreshold = 2;
  #     extraArgs = [
  #         "-g" "--avoid '^(X|plasma.*|konsole|kwin)$'"
  #         "--prefer '^(electron|libreoffice|gimp)$'"
  #     ];
  # };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.android_sdk.accept_license = true;

  # FIXME: There is probably some conflicts in this confiuation
  networking.nameservers = [ "1.1.1.1" "1.1.0.1" "8.8.8.8" ];

  services = {
    nixops-dns.domain = "1.1.1.1";
    fstrim.enable = true;
    journald.extraConfig = ''
      SystemMaxUse=2G
    '';
  };

  nix = {
    settings = {
      auto-optimise-store = true;
      substituters = [
        "https://nix-gaming.cachix.org"
        "https://nix-community.cachix.org"
        "https://cache.nixos.org/"
        "https://hyprland.cachix.org"
        "https://vicinae.cachix.org"

        # From zed flake
        "https://cache.garnix.io"
        "https://zed.cachix.org"

        # RocksDB still builds locally, probably issue on their end, I'm not sure what's the point of this cache
        # "https://attic.kennel.juneis.dog/conduit"
      ];
      trusted-public-keys = [
        "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="

        # From zed flake
        "zed.cachix.org-1:/pHQ6dpMsAZk2DiP4WCL0p9YDNKWj2Q5FL20bNmw1cU="
        "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="

        # "conduit:eEKoUwlQGDdYmAI/Q/0slVlegqh/QmAvQd7HBSm21Wk="
      ];
      experimental-features = [ "nix-command" "flakes" ];
    };
    gc = {
      automatic = true;
      dates = "monthly";
      options = "--delete-older-than 30d";
    };
  };

  systemd = {
    settings.Manager = {
      DefaultTimeoutStopSec = "10s";
      DefaultTimeoutStartSec = "10s";
    };

    coredump = {
      enable = true;
      extraConfig = "ExternalSizeMax=${toString (8 * 1024 * 1024 * 1024)}";
    };
  };

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
    noto-fonts
    noto-fonts-color-emoji
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-cjk-sans-static
    noto-fonts-cjk-serif-static
    inter
    roboto
    noto-fonts
    noto-fonts-color-emoji
    twemoji-color-font
  ];

  # WARNING: Do not toch, firefox will fucking explode
  fonts.fontconfig.localConf = ''
    <fontconfig>
      <alias>
        <family>Apple Color Emoji</family>
        <prefer><family>Twitter Color Emoji</family></prefer>
      </alias>
      <alias>
        <family>Segoe UI Emoji</family>
        <prefer><family>Twitter Color Emoji</family></prefer>
      </alias>
      <alias>
        <family>Noto Color Emoji</family>
        <prefer><family>Twitter Color Emoji</family></prefer>
      </alias>
      <alias>
        <family>emoji</family>
        <prefer><family>Twitter Color Emoji</family></prefer>
      </alias>
    </fontconfig>
  '';

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

    # SayoDevice O3C v1 keyboard (specific device by serial number)
    SUBSYSTEM=="usb", ATTRS{idVendor}=="8089", ATTRS{idProduct}=="0009", ATTRS{serial}=="03CDAB10239BBC788B39E339E300", MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"
    KERNEL=="hidraw*", ATTRS{idVendor}=="8089", ATTRS{idProduct}=="0009", ATTRS{serial}=="03CDAB10239BBC788B39E339E300", MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"

    # SayoDevice O3C v1 keyboard bootloader mode (for firmware updates)
    SUBSYSTEM=="usb", ATTRS{idVendor}=="8089", ATTRS{idProduct}=="0005", ATTRS{serial}=="00CDAB10239BBC788B39E339E300", MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"
    KERNEL=="hidraw*", ATTRS{idVendor}=="8089", ATTRS{idProduct}=="0005", ATTRS{serial}=="00CDAB10239BBC788B39E339E300", MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"
 '';

  # Allow plugdev access to ANNE PRO 2
  # https://github.com/sizezero/dev-notes/blob/master/anne-pro-2.org
  # services.udev.extraRules = ''
  #   SUBSYSTEM=="input", GROUP="input", MODE="0666"
  #   # For ANNE PRO 2
  #   SUBSYSTEM=="usb", ATTRS{idVendor}=="04d9", ATTRS{idProduct}=="8008",
  #   MODE="0666", GROUP="plugdev"
  #   KERNEL=="hidraw*", ATTRS{idVendor}=="04d9", ATTRS{idProduct}=="8008",
  #   MODE="0660", GROUP="plugdev"
  # '';

  networking.networkmanager.enable = true;

  sleroq = {
    tailscale.enable = true;
    apps.enable = true;
    # flatpakIntegration.enable = true;
    kwallet.enable = false;
    sound.enable = true;
    wms.enable = true;
    workVpn = {
      enable = true;
      secretsPath = ./secrets/work-vpn;
      username = secrets.work-vpn.username;
      port = secrets.work-vpn.port;
      remotes = secrets.work-vpn.remotes;
    };
  };

  # Mouse fix for gaming
  services.libinput.mouse.additionalOptions = ''
    [Never Debounce]
    MatchUdevType=mouse
    ModelBouncingKeys=1
  '';

  age.secrets.sing-box-outbounds = {
    file = ./secrets/sing-box-outbounds.jsonc;
    mode = "0644";
  };

  sleroq.sing-box = {
    enable = true;
    useTunMode = false;
    settings = {
      # log.level = "warn";
      outbounds = {
        _secret = config.age.secrets.sing-box-outbounds.path;
        quote = false;
      };
    };
  };

  programs.firefox = {
    enable = true;
    autoConfig = builtins.readFile(builtins.fetchurl {
      url = "https://raw.githubusercontent.com/MrOtherGuy/fx-autoconfig/master/program/config.js";
      sha256 = "1mx679fbc4d9x4bnqajqx5a95y1lfasvf90pbqkh9sm3ch945p40";
    });
  };
}
