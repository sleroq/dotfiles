#!/usr/bin/env bash
# Exercise the actual kernel/initrd with the VPS's virtio-scsi root controller.
# Only root discovery/mounting is tested: the dummy disk has no NixOS closure.
# Run on cumserver: QEMU=/path/to/qemu-system-x86_64 bash check-initrd.sh SYSTEM UUID LOG
set -euo pipefail

system=$1
uuid=$2
log=$3
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

truncate -s 128M "$work/root.img"
printf 'label: dos\nstart=2048, type=83\n' | sfdisk "$work/root.img" >/dev/null
mkfs.ext4 -q -F -b 1024 -U "$uuid" -E offset=1048576 "$work/root.img" 130048

result=0
timeout 45s "$QEMU" \
  -accel tcg -m 512 -smp 1 -nographic -nic none -no-reboot \
  -kernel "$system/kernel" -initrd "$system/initrd" \
  -append "console=ttyS0 root=fstab init=$system/init systemd.show_status=yes" \
  -device virtio-scsi-pci,id=scsi0 \
  -drive "file=$work/root.img,format=raw,if=none,id=rootdisk" \
  -device scsi-hd,drive=rootdisk,bus=scsi0.0 >"$log" 2>&1 || result=$?

if [[ $result != 0 && $result != 124 ]]; then
  tail -n 20 "$log"
  exit "$result"
fi

# Check the kernel's mount event, not systemd's colour-formatted status text.
if grep -Fq "mounted filesystem $uuid" "$log"; then
  echo "PASS: virtio-scsi root filesystem mounted ($system)"
else
  echo "FAIL: virtio-scsi root filesystem did not mount; see $log" >&2
  exit 1
fi
