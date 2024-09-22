{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    virtiofsd
    quickemu
    distrobox

    dive # look into docker image layers
    podman-tui # status of containers in the terminal
    docker-compose # start group of containers for dev
  ];

  programs.virt-manager.enable = true;

  virtualisation = {
    containers.enable = true;
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
      dockerSocket.enable = true;
    };
    # waydroid.enable = true;
    lxd.enable = true;
    libvirtd.enable = true;
    spiceUSBRedirection.enable = true;
  };

  services.spice-vdagentd.enable = true;
}
