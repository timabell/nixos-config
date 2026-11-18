#!/usr/bin/env bash
# Tear down the devvm libvirt domain. Leaves the qcow2 disk on the host
# untouched — delete it manually if you also want fresh storage.
#
# Pass --disk to also remove the qcow2 image (full wipe).

set -euo pipefail

NAME=devvm
DISK=/var/lib/libvirt/images/devvm.qcow2

WIPE_DISK=0
for arg in "$@"; do
  case $arg in
    --disk) WIPE_DISK=1 ;;
    *) echo "unknown arg: $arg" >&2; exit 1 ;;
  esac
done

if virsh domstate "$NAME" >/dev/null 2>&1; then
  virsh destroy "$NAME" 2>/dev/null || true
  virsh undefine "$NAME" --nvram
  echo "Undefined libvirt domain '$NAME'."
else
  echo "No libvirt domain '$NAME' to remove."
fi

if [[ $WIPE_DISK -eq 1 ]]; then
  if [[ -f $DISK ]]; then
    sudo rm -f "$DISK"
    echo "Removed disk image $DISK."
  else
    echo "Disk image $DISK already absent."
  fi
else
  if [[ -f $DISK ]]; then
    echo "Disk image kept at $DISK (pass --disk to remove it too)."
  fi
fi
