{
  config,
  pkgs,
  username,
  lib,
  ...
}:
let
  tailscaleCfg = config.services.tailscale;
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  # The generated disk-swap UUID no longer exists; use the shared zram swap.
  swapDevices = lib.mkForce [ ];

  hardware.amdgpu.initrd.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services.blueman.enable = true;
  sleroq.wms.dwl.enable = true;
  programs.hyprland.enable = lib.mkForce false;

  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    # Sunshine is only reachable through the already-trusted Tailscale interface.
    openFirewall = false;
    settings.csrf_allowed_origins = "https://100.82.25.59:47990";
  };

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
      verbose = false;
      luks.devices."luks-972627b2-2690-4d15-be64-d03f0aa85255".allowDiscards = true;
      systemd.enable = true;
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

  services.logind.settings.Login = {
    # don’t shutdown when power button is short-pressed
    HandlePowerKey = "ignore";
  };

  environment.variables = {
    # https://wiki.archlinux.org/title/Hardware_video_acceleration#Configuring_Vulkan_Video
    RADV_PERFTEST = "video_decode,video_encode";
  };

  networking.hostName = "sleroq-interplanetary"; # TODO: infer from flake definition somehow
  # NetworkManager must not flush addresses owned by tailscaled.
  networking.networkmanager.unmanaged = [ "interface-name:${tailscaleCfg.interfaceName}" ];

  hardware.opentabletdriver.enable = true;
  hardware.opentabletdriver.daemon.enable = true;

  services.udev.extraRules = ''
    # This Bluetooth USB controller failed runtime suspend; keep only it awake.
    ACTION=="add|bind", SUBSYSTEM=="pci", KERNEL=="0000:11:00.0", ATTR{power/control}="on"

    KERNEL=="hidraw*", ATTRS{idVendor}=="056a", MODE="0660", GROUP="users", TAG+="uaccess"
    SUBSYSTEM=="usb", ATTR{idVendor}=="0ac3", MODE="0660", GROUP="users", TAG+="uaccess"
  '';

  # programs.anime-game-launcher.enable = true;
  # programs.anime-games-launcher.enable = true;

  environment.systemPackages = [
    pkgs.freerdp
    pkgs.android-tools
  ]; # FIXME: Is this not included in remmina package or whatever?

  # Define a user account
  users.defaultUserShell = pkgs.bash;
  users.users.${username} = {
    shell = pkgs.nushell;
    isNormalUser = true;
    description = "The main user";
    extraGroups = [
      "networkmanager"
      "input"
      "wheel"
      "video"
      "libvirtd"
      "adbusers"
      "uinput"
      "kvm"
      "gamemode"
    ];

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

  age.identityPaths = [ "/var/lib/agenix-key.txt" ];
  sleroq.virtualisation.enable = true;
  # Direct sing-box outbounds intentionally return through the physical
  # interface while the unmarked default route points at tun0. Strict reverse
  # path filtering drops those replies before they reach the marked socket.
  networking.firewall.checkReversePath = "loose";
  # There is no upstream IPv6 route. Advertising one through the TUN makes
  # browsers use IPv6 for Steam's direct CDN traffic, which sing-box cannot dial.
  sleroq.sing-box.enableIPv6 = false;
  sleroq.sing-box.routeExcludeAddresses = [
    # OS route bypasses for LAN/VPN address space. The current proxy
    # endpoint also needs an OS route bypass
    # with plain auto_route; auto_detect_interface does not prevent its outer
    # connection from re-entering tun0 on this host.
    "45.144.51.81/32" # node1.yamarkov.ru, selected proxy endpoint.
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "100.64.0.0/10" # Tailscale CGNAT range.
    "224.0.0.0/4" # Local IPv4 multicast.
    "fc00::/7" # Private IPv6 LAN/VPN space.
    "fe80::/10" # IPv6 link-local traffic.
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
