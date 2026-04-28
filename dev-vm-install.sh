#!/usr/bin/env bash
# Define the devvm libvirt domain and start it.
#
# Run this on the host AFTER you've copied the qcow2 to libvirt's images
# dir and resized it (see dev-vm.md steps 4–5). Idempotency is up to you:
# `virt-install` will fail if the domain already exists — `virsh undefine
# devvm --remove-all-storage` to start over.

set -euo pipefail

# --- adjust these for your host ---
NAME=devvm
MEMORY_MIB=8192
VCPUS=4
DISK=/var/lib/libvirt/images/devvm.qcow2
# To enable the virtiofs shared folder, install `virtiofsd` on the host, set
# SHARE_DIR, and uncomment the two flags marked "virtiofs" below.
# SHARE_DIR=$HOME/devvm-share   # host dir exposed to the VM as /home/tim/work
# ----------------------------------

if [[ ! -f $DISK ]]; then
  echo "error: $DISK not found. Build and copy the qcow2 first (see dev-vm.md)." >&2
  exit 1
fi

# mkdir -p "$SHARE_DIR"   # virtiofs

virt-install \
  --name "$NAME" \
  --memory "$MEMORY_MIB" \
  --vcpus "$VCPUS" \
  --cpu host-passthrough \
  --boot firmware=efi,firmware.feature0.name=secure-boot,firmware.feature0.enabled=no,firmware.feature1.name=enrolled-keys,firmware.feature1.enabled=no \
  --disk "path=$DISK,bus=virtio" \
  --osinfo linux2022 \
  --network network=default,model=virtio \
  --graphics spice,listen=none \
  --video virtio \
  --import \
  --noautoconsole
  # UEFI Secure Boot is disabled because NixOS systemd-boot isn't signed
  # against the default Microsoft keys; with SB on, OVMF rejects the
  # bootloader with "Access Denied".
  #
  # virtiofs (requires virtiofsd installed on host):
  # --memorybacking source.type=memfd,access.mode=shared \
  # --filesystem "driver.type=virtiofs,source=$SHARE_DIR,target=shared" \

echo
echo "Defined and started libvirt domain '$NAME'."
echo "Open the console with:  virt-viewer $NAME"
echo "Or in virt-manager — it'll be in the list."
