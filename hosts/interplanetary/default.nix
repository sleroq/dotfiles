{ config, pkgs, self, username, lib, ... }:
let
  tailscaleStateDir = "/boot/tailscale-initrd";
  initrdTailscaleState = "${tailscaleStateDir}/tailscaled.state";
  initrdSshHostKey = "/boot/initrd-ssh/ssh_host_ed25519_key";
  tailscaleCfg = config.services.tailscale;
in
{
  imports = [
    ./hardware-configuration.nix
    "${self}/modules/webdav.nix"
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
      availableKernelModules = lib.mkAfter [
        "r8169"
        "tun"
        "nft_chain_nat"
      ];
      network = {
        enable = true;
        ssh = {
          enable = true;
          hostKeys = [ initrdSshHostKey ];
          authorizedKeys = config.users.users.${username}.openssh.authorizedKeys.keys;
          ignoreEmptyHostKeys = true;
        };
      };
      verbose = false;
      luks.devices."luks-972627b2-2690-4d15-be64-d03f0aa85255" = {
        device = "/dev/disk/by-uuid/972627b2-2690-4d15-be64-d03f0aa85255";
        allowDiscards = true;
      };
      systemd = {
        enable = true;
        users.root.shell = "${pkgs.bashInteractive}/bin/bash";
        packages = [ tailscaleCfg.package ];
        storePaths = [ pkgs.bashInteractive ];
        extraBin = {
          ping = "${pkgs.iputils}/bin/ping";
        };
        mounts = [
          {
            what = "/dev/disk/by-uuid/AF7D-6D7E";
            where = "/boot";
            type = "vfat";
            options = "fmask=0077,dmask=0077";
            wantedBy = [ "initrd.target" ];
            before = [ "initrd.target" ];
            unitConfig.DefaultDependencies = false;
          }
        ];
        network = {
          enable = true;
          wait-online = {
            anyInterface = true;
            timeout = 20;
          };
          networks = {
            "10-enp16s0" = {
              matchConfig.Name = "enp16s0";
              networkConfig.DHCP = "ipv4";
              linkConfig.RequiredForOnline = "routable";
            };
            "50-tailscale" = {
              matchConfig.Name = tailscaleCfg.interfaceName;
              linkConfig = {
                Unmanaged = true;
                ActivationPolicy = "manual";
              };
            };
          };
        };
        services = {
          systemd-networkd-wait-online.requiredBy = [ "network-online.target" ];
          tailscaled = {
            unitConfig.DefaultDependencies = false;
            wantedBy = [ "initrd.target" ];
            wants = [ "network-online.target" ];
            requires = [ "boot.mount" ];
            after = [
              "boot.mount"
              "network-online.target"
            ];
            path = [
              pkgs.iptables
              pkgs.iproute2
              tailscaleCfg.package
            ];
            serviceConfig = {
              # Keep initrd Tailscale disabled until a separate node state exists on /boot.
              ExecStart = ''${tailscaleCfg.package}/bin/tailscaled --state=${lib.escapeShellArg initrdTailscaleState} --socket=/run/tailscale/tailscaled.sock --port=${toString tailscaleCfg.port} --tun ${lib.escapeShellArg tailscaleCfg.interfaceName}'';
              Restart = "on-failure";
              RuntimeDirectory = "tailscale";
              RuntimeDirectoryMode = "0755";
              Type = "notify";
            };
            unitConfig.ConditionPathExists = initrdTailscaleState;
          };
        };
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

  networking.hostName = "sleroq-interplanetary"; # TODO: infer from flake definition somehow

  hardware.opentabletdriver.enable = true;
  hardware.opentabletdriver.daemon.enable = true;

  # programs.anime-game-launcher.enable = true;
  # programs.anime-games-launcher.enable = true;

  environment.systemPackages = [ pkgs.freerdp pkgs.android-tools ]; # FIXME: Is this not included in remmina package or whatever?

  # Define a user account
  users.defaultUserShell = pkgs.bash;
  users.users.${username} = {
    shell = pkgs.nushell;
    isNormalUser = true;
    description = "The main user";
    extraGroups = [ "networkmanager" "input" "wheel" "video" "libvirtd" "adbusers" "uinput" "kvm" "gamemode" ];

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDSh54pu9bAH8DFBKPtswFJzevCft+gHZStJQ0trYGoj sleroq@cum.army"
    ];
  };

  # This allows to run electron from node_modules and other things
  # but I need to keep this in mind when making nix packages
  # btw Stardew Valley SMAPI does not work with nix-ld enabled lol
  # programs.nix-ld.enable = true;
  # programs.nix-ld.libraries = with pkgs; [
    # Add any missing dynamic libraries for unpackaged programs
    # here, NOT in environment.systemPackages
  # ];

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
    };
  };

  systemd.tmpfiles.rules = [
    "d /boot/initrd-ssh 0700 root root -"
    "d ${tailscaleStateDir} 0700 root root -"
  ];

  systemd.services.initrd-ssh-host-key = {
    description = "Generate initrd SSH host key";
    wantedBy = [ "multi-user.target" ];
    after = [ "boot.mount" ];
    # The first switch creates the key on /boot; rebuild once more so it is embedded into initrd.
    unitConfig.ConditionPathExists = "|!${initrdSshHostKey}";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ pkgs.openssh ];
    script = ''
      install -d -m 0700 /boot/initrd-ssh
      ssh-keygen -q -t ed25519 -N "" -f ${lib.escapeShellArg initrdSshHostKey}
    '';
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
