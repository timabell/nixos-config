#!/usr/bin/env bash
# Build the bare devvm image, copy it into libvirt's images dir, resize
# it, then define and start the VM. Run on the host; host setup (Nix,
# libvirt) is in devvm/README.md. First boot steps are printed at the end.

set -euo pipefail
cd "$(dirname "$0")/.."

DISK=/var/lib/libvirt/images/devvm.qcow2

# The disk holds the VM's state once it has booted; never overwrite it.
if [[ -e $DISK ]]; then
  echo "error: $DISK already exists. Run devvm/delete.sh --disk first to start over." >&2
  exit 1
fi

# User libvirt runs qemu as: NixOS / Debian / Fedora+Arch.
for QEMU_USER in qemu-libvirtd libvirt-qemu qemu; do
  id "$QEMU_USER" >/dev/null 2>&1 && break
  QEMU_USER=
done
if [[ -z $QEMU_USER ]]; then
  echo "error: no libvirt qemu user found. Is libvirt installed?" >&2
  exit 1
fi

# Bare config only: small closure, so cptofs packs it in minutes. The
# full config is switched to inside the VM, fetched from cache.nixos.org.
# --no-link: no result symlink, so the store copy can be GC'd later.
echo "+ nix build .#devvm-base --no-link --print-out-paths"
OUT=$(nix build .#devvm-base --no-link --print-out-paths)

echo "+ sudo mkdir -p /var/lib/libvirt/images"
sudo mkdir -p /var/lib/libvirt/images

# qcow2 under btrfs CoW fragments badly with heavy writes (npm install).
# Only affects files created after it's set, so do it before the copy.
if [[ $(stat -f -c %T /var/lib/libvirt/images) == btrfs ]]; then
  echo "+ sudo chattr +C /var/lib/libvirt/images"
  sudo chattr +C /var/lib/libvirt/images
fi

# Copy out of the store: the store copy is read-only.
echo "+ sudo install -o $QEMU_USER -g $QEMU_USER -m 0660 $OUT/devvm-base.qcow2 $DISK"
sudo install -o "$QEMU_USER" -g "$QEMU_USER" -m 0660 "$OUT/devvm-base.qcow2" "$DISK"

# Built tiny (~4G) because cptofs/LKL OOMs on a big ext4 at build time.
# qcow2 is sparse so 80G is a cap, not an allocation; growPartition +
# autoResize grow the filesystem on first boot.
echo "+ sudo qemu-img resize $DISK 80G"
sudo qemu-img resize "$DISK" 80G

# Free the ~2.4G store copy now it's been copied out. A result link from
# a manual `nix build .#devvm-base` would keep it alive, so drop that too.
if [[ $(readlink result 2>/dev/null) == "$OUT" ]]; then
  echo "+ rm result"
  rm result
fi
echo "+ nix store delete $OUT"
nix store delete "$OUT" || echo "warning: $OUT still referenced, not deleted"

echo "+ devvm/define.sh"
devvm/define.sh

echo
echo "Next, inside the VM:"
echo "  passwd    # default is changeme"
echo "  ping -c1 cache.nixos.org"
echo "  cd ~/repo/nixos-config && ./update-current-host.sh"
echo "  sudo reboot"
