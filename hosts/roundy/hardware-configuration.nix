{ lib, secrets, ... }:

{
  boot.initrd.availableKernelModules = [
    "ata_piix"
    "virtio_pci"
    # The root disk is attached through virtio-scsi, not virtio-blk.
    "virtio_scsi"
    "floppy"
    "sr_mod"
    "virtio_blk"
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/${secrets.rootUuid}";
    fsType = "ext4";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
