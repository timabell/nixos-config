#!/usr/bin/env bash
# Grow the devvm disk, e.g. `devvm/resize.sh 200G`. Shuts the VM down
# cleanly, raises the qcow2 cap and boots it again; growPartition +
# autoResize grow the filesystem on boot. Grow only: qemu-img refuses to
# shrink without --shrink, which would cut off data.
# Mind the host's free space: the VM can fill the qcow2 up to this cap.

set -euo pipefail

export LIBVIRT_DEFAULT_URI=qemu:///system
NAME=devvm
DISK=/var/lib/libvirt/images/devvm.qcow2

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <new size, e.g. 150G>" >&2
  exit 1
fi
SIZE=$1

if [[ $(virsh domstate "$NAME") != "shut off" ]]; then
  echo "+ virsh shutdown $NAME"
  virsh shutdown "$NAME"
  # Wait for the guest to power off. No forced destroy: that's a pulled plug.
  for _ in $(seq 120); do
    [[ $(virsh domstate "$NAME") == "shut off" ]] && break
    sleep 1
  done
  if [[ $(virsh domstate "$NAME") != "shut off" ]]; then
    echo "error: $NAME didn't shut down within 2 minutes. Shut it down from inside, then re-run." >&2
    exit 1
  fi
fi

echo "+ sudo qemu-img resize $DISK $SIZE"
sudo qemu-img resize "$DISK" "$SIZE"

echo "+ virsh start $NAME"
virsh start "$NAME"

echo
echo "Check inside the VM once it's booted:  df -h /"
