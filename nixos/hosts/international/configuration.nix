{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/battery-life.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  boot.initrd.systemd.enable = true;
  boot.plymouth.enable = true;
  boot.kernel.sysctl = { "vm.swappiness" = 20; };
  boot.kernelParams = [ "quiet" ];
  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
  boot.kernelModules = [ "v4l2loopback" ];  # obs virtual camera

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

  networking.wireless.iwd.enable = true;
  # Enable networking
  networking.networkmanager = {
    enable = true;
    wifi.backend = "iwd";
  };

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # Define a user account
  users.defaultUserShell = pkgs.bash;
  users.users.sleroq = {
    shell = pkgs.nushell;
    isNormalUser = true;
    description = "sleroq";
    extraGroups = [ "networkmanager" "input" "wheel" "docker" "video" "libvirtd" "adbusers" ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.11"; # Did you read the comment?
}
