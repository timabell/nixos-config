#!/usr/bin/env bash
# Bootstrap a fleet host straight onto its internal disk from a live Linux
# environment (e.g. a Mint live USB), for when the NixOS installer ISO
# won't UEFI-boot on the hardware (seen on the Framework 16, whose
# early firmware exposes no Secure Boot toggle and refuses the NixOS ISO).
#
# This uses NixOS's own disko-install — the live environment is just a
# launcher. Nothing is written to it permanently; the Nix install below
# lives under /nix and is gone when the live USB reboots.
#
# Run it from a checkout of THIS repo, on the branch that defines the host:
#   git clone https://github.com/timabell/nixos-config.git
#   cd nixos-config
#   ./install-from-live-mint.sh cog /dev/nvme0n1
#
# WARNING: disko-install ERASES the target disk.

set -euo pipefail

HOST="${1:-}"
DISK="${2:-/dev/nvme0n1}"

if [[ -z $HOST ]]; then
  echo "usage: $0 <host> [disk]   e.g. $0 cog /dev/nvme0n1" >&2
  exit 1
fi

# 1. Nix — install it if the live environment doesn't already have it. The
#    daemon install lives under /nix and vanishes when the live USB reboots.
if ! command -v nix >/dev/null 2>&1; then
  echo "==> Installing Nix (ephemeral: gone when the live USB reboots)"
  sh <(curl -L https://nixos.org/nix/install) --daemon
  # Make nix available in THIS shell without opening a new one.
  for profile in \
    /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
    "$HOME/.nix-profile/etc/profile.d/nix.sh"; do
    # shellcheck disable=SC1090
    [[ -e $profile ]] && . "$profile"
  done
fi

# sudo resets PATH and root never sourced the Nix profile, so `sudo nix`
# fails with "not found". Hand sudo the absolute path instead.
NIX="$(command -v nix)"

# 2. Show the disks so a wrong target is obvious before anything is wiped.
echo "==> Block devices:"
lsblk

cat <<EOF

About to install host '$HOST' onto '$DISK'.
THIS WILL ERASE ALL DATA ON $DISK.
EOF


read -r -p "Re-type the disk path to confirm: " confirm
if [[ $confirm != "$DISK" ]]; then
  echo "Confirmation did not match; aborting." >&2
  exit 1
fi

# 3. Partition + install straight onto the internal disk. `.#$HOST` reads
#    the flake in the current directory, so make sure the branch that
#    defines $HOST is checked out here.
echo "==> Running disko-install for .#$HOST on $DISK"
sudo "$NIX" --extra-experimental-features 'nix-command flakes' \
  run 'github:nix-community/disko/latest#disko-install' -- \
  --flake ".#$HOST" \
  --disk main "$DISK"

cat <<EOF

Done. Reboot, remove the live USB, and the machine should boot '$HOST'.
You'll be prompted for the LUKS passphrase you set during install.
EOF
