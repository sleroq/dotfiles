{ config, pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    virt-manager
    virtiofsd
  ];

  virtualisation = {
    # docker.enable = true;
    # waydroid.enable = true;
    lxd.enable = true;
    libvirtd.enable = true;
    spiceUSBRedirection.enable = true;
  };
  services.spice-vdagentd.enable = true;
}
