{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # virtiofsd
    # quickemu
    # virtio-win

    distrobox
    dive # look into docker image layers
    podman-tui # status of containers in the terminal
    podman-compose # start group of containers for dev
  ];

  # programs.virt-manager.enable = true;

  virtualisation = {
    containers.enable = true;
    # docker = {
    #   enable = true;
    #   autoPrune.enable = true;
    # };

    podman = {
      enable = true;

      dockerCompat = true;
      dockerSocket.enable = true;

      defaultNetwork.settings.dns_enabled = true;
      autoPrune.enable = true;
    };
    # waydroid.enable = true;
    # lxd.enable = true;
    # libvirtd.enable = true;
    # spiceUSBRedirection.enable = true;
  };

  # services.spice-vdagentd.enable = true;
}
