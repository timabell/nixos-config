#!/usr/bin/env bash
# Install host-side prerequisites for running the devvm: libvirt + KVM,
# virt-manager, OVMF (UEFI firmware for the guest), virtiofsd (host-side
# daemon for virtiofs shared folders).
#
# Debian / Ubuntu only. Idempotent — safe to re-run.

set -euo pipefail

sudo apt-get update
sudo apt-get install -y \
  libvirt-daemon-system libvirt-clients \
  qemu-system-x86 qemu-utils \
  virt-manager virt-viewer \
  ovmf \
  virtiofsd

sudo systemctl enable --now libvirtd

if getent group libvirt >/dev/null; then
  sudo usermod -aG libvirt "$USER"
  echo "Added $USER to libvirt group. Log out and back in for it to take effect."
fi

echo "Done."
