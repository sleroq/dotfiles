{ config, pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    virt-manager
    virtiofsd
    quickemu
    distrobox
  ];

  virtualisation = {
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };
    # waydroid.enable = true;
    lxd.enable = true;
    libvirtd.enable = true;
    spiceUSBRedirection.enable = true;
  };
  services.spice-vdagentd.enable = true;
}
