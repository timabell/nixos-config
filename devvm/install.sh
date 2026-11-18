#!/usr/bin/env bash
# Define the devvm libvirt domain and start it.
#
# Run this on the host AFTER you've copied the qcow2 to libvirt's images
# dir and resized it (see devvm/README.md). Idempotency is up to you:
# `virt-install` will fail if the domain already exists — `virsh undefine
# devvm --remove-all-storage` to start over.

set -euo pipefail

# Non-root defaults to qemu:///session, which runs as you and can't read the system images dir.
export LIBVIRT_DEFAULT_URI=qemu:///system

# --- adjust these for your host ---
NAME=devvm
MEMORY_MIB=8192
VCPUS=4
DISK=/var/lib/libvirt/images/devvm.qcow2
SHARE_DIR=$HOME/no-sync/devvm   # host dir, auto-mounted in the VM at /home/tim/work (hosts/devvm.nix)
SHARE_TAG=work
REPO_DIR=$HOME/repo   # host dir, auto-mounted in the VM at /home/tim/repo; RW, see security-boundaries.md
REPO_TAG=repo
# ----------------------------------

if [[ ! -f $DISK ]]; then
  echo "error: $DISK not found. Build and copy the qcow2 first (see devvm/README.md)." >&2
  exit 1
fi

echo "+ mkdir -p $SHARE_DIR"
mkdir -p "$SHARE_DIR"
echo "+ mkdir -p $REPO_DIR"
mkdir -p "$REPO_DIR"

virt-install \
  --name "$NAME" \
  --memory "$MEMORY_MIB" \
  --vcpus "$VCPUS" \
  --cpu host-passthrough \
  --boot firmware=efi,firmware.feature0.name=secure-boot,firmware.feature0.enabled=no,firmware.feature1.name=enrolled-keys,firmware.feature1.enabled=no \
  --disk "path=$DISK,bus=virtio,cache=writeback,discard=unmap" \
  --osinfo linux2022 \
  --network network=default,model=virtio \
  --graphics spice,listen=none \
  --video virtio \
  --memorybacking source.type=memfd,access.mode=shared \
  --filesystem "driver.type=virtiofs,source=$SHARE_DIR,target=$SHARE_TAG" \
  --filesystem "driver.type=virtiofs,source=$REPO_DIR,target=$REPO_TAG" \
  --import \
  --noautoconsole
  # UEFI Secure Boot is disabled because NixOS systemd-boot isn't signed
  # against the default Microsoft keys; with SB on, OVMF rejects the
  # bootloader with "Access Denied".
  #
  # Disk tuning (npm-install scale write storms otherwise crawl):
  #   cache=writeback  - use host page cache. Big speedup; tiny crash risk.
  #   discard=unmap    - trim/discard, keeps the qcow2 sparse over time.
  # io=native would also help but libvirt requires cache=none|directsync
  # for it; the writeback host-cache speedup is the bigger win.
  # Multi-queue virtio-blk (queues=$VCPUS) too, but virt-install on older
  # versions doesn't accept it. Add post-create via virt-xml if you want:
  #   virt-xml devvm --edit target=vda --disk queues=$VCPUS
  #
  # virtiofs needs `virtiofsd` installed on the host and shared memory
  # backing (--memorybacking above). Near-native perf, handles big trees
  # with many small files (build outputs, node_modules, etc.).

echo
echo "Defined and started libvirt domain '$NAME'."
echo "Open the console with:  virt-viewer $NAME"
echo "Or in virt-manager — it'll be in the list."
