{ config, pkgs, self, inputs', ... }:

{
  imports = [
    ./hardware-configuration.nix
    "${self}/modules/webdav.nix"
  ];

  hardware.amdgpu.initrd.enable = true;

  # Bootloader.
  boot = {
    kernelPackages = pkgs.linuxKernel.packages.linux_xanmod;
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

    # kernel.sysctl = { "vm.swappiness" = 10; };
    extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
    kernelModules = [ "v4l2loopback" ]; # obs virtual camera

    # Hide the OS choice for bootloaders.
    # It's still possible to open the bootloader list by pressing any key
    # It will just not appear on screen unless a key is pressed
    loader.timeout = 0;
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
  };

  services.system76-scheduler.enable = true;

  powerManagement.cpuFreqGovernor = "performance";

  services.logind.settings.Login = {
    # don’t shutdown when power button is short-pressed
    HandlePowerKey = "ignore";
  };

  environment.variables = {
    # https://wiki.archlinux.org/title/Hardware_video_acceleration#Configuring_Vulkan_Video
    RADV_PERFTEST = "video_decode,video_encode";
  };

  networking.hostName = "sleroq-interplanetary";

  hardware.opentabletdriver.enable = true;
  hardware.opentabletdriver.daemon.enable = true;

  programs.anime-game-launcher.enable = true;
  programs.anime-games-launcher.enable = true;
  programs.adb.enable = true; # Phone debuggin stuff

  environment.systemPackages = [
    inputs'.winapps.packages.winapps
    inputs'.winapps.packages.winapps-launcher # optional
    pkgs.freerdp
  ];

  # Define a user account
  users.defaultUserShell = pkgs.bash;
  users.users.sleroq = {
    shell = pkgs.nushell;
    isNormalUser = true;
    description = "sleroq";
    extraGroups = [ "networkmanager" "input" "wheel" "video" "libvirtd" "adbusers" "uinput" ];

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDSh54pu9bAH8DFBKPtswFJzevCft+gHZStJQ0trYGoj sleroq@cum.army"
    ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
    };
  };

  age.secrets = {
    webdav-cert = {
      file = "${self}/shared/secrets/webdav-cert.pem";
      mode = "0644";
      owner = "webdav";
      group = "webdav";
    };
    webdav-key = {
      file = "${self}/shared/secrets/webdav-key.pem";
      mode = "0600";
      owner = "webdav";
      group = "webdav";
    };
  };
  sleroq.webdav = {
    enable = true;
    port = 8092;
    directory = "/srv/webdav";
    permissions = "CRUD";
    debug = false;
    openFirewall = true;
    tls = {
      enable = true;
      certFile = config.age.secrets.webdav-cert.path;
      keyFile = config.age.secrets.webdav-key.path;
    };
  };
  sleroq.virtualisation.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
