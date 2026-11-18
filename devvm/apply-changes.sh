#!/usr/bin/env bash
# Apply changes to devvm/define.sh (shares, memory, CPUs) to the existing VM.
# libvirt only reads those at define time, so this shuts the VM down
# cleanly, undefines it and redefines it. The qcow2 disk is never touched.
# Changes to the VM's NixOS config are applied inside the VM instead.

set -euo pipefail
cd "$(dirname "$0")/.."

export LIBVIRT_DEFAULT_URI=qemu:///system
NAME=devvm

if virsh domstate "$NAME" >/dev/null 2>&1; then
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

  # --nvram: otherwise the old Secure Boot NVRAM lingers and the new domain inherits it.
  # No --remove-all-storage, so the disk stays.
  echo "+ virsh undefine $NAME --nvram"
  virsh undefine "$NAME" --nvram
fi

echo "+ devvm/define.sh"
devvm/define.sh
