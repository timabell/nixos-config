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
#   sudo apt update && sudo apt install git
#   git clone https://github.com/timabell/nixos-config.git
#   cd nixos-config
#   ./install-from-live-mint.sh cog-base /dev/nvme0n1
#
# For a full desktop host the closure is too big to realise in a live
# USB's RAM-backed store, so install the minimal '<host>-base' config here
# (small), then after booting it run `nixos-rebuild switch --flake .#<host>`
# to build the full system into the real on-disk store. Pass the plain
# '<host>' only if its closure is known to fit.
#
# WARNING: disko-install ERASES the target disk.

set -euo pipefail

HOST="${1:-}"
DISK="${2:-/dev/nvme0n1}"

if [[ -z $HOST ]]; then
  echo "usage: $0 <host> [disk (default $DISK)]" >&2
  echo "e.g. $0 cog-base" >&2
  echo "or $0 cog-base $DISK" >&2
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
#
#    nixos-install (which disko-install invokes) calls `mount`/`umount`
#    without putting them on PATH. The failing call runs AFTER
#    nixos-install chroots into the target, so the host's /usr/bin/mount
#    is out of reach — but env vars propagate into the chroot, where
#    /nix/var/nix/profiles/system/sw/bin resolves to the target's own
#    util-linux. Put that first; host dirs cover the pre-chroot calls.
#    https://github.com/NixOS/nixpkgs/issues/220211
#    https://github.com/nix-community/disko/issues/1242
#    https://discourse.nixos.org/t/nixos-install-mount-command-not-found/59197/10
#    https://github.com/viluon/nixos/blob/92f1a9dac6ce62b357ee33552ea6fd4bbe1eea9c/README.md#panic-at-the-disko
echo "==> Running disko-install for .#$HOST on $DISK"
sudo env PATH="/nix/var/nix/profiles/system/sw/bin:/usr/sbin:/sbin:/usr/bin:/bin:$PATH" \
  "$NIX" --extra-experimental-features 'nix-command flakes' \
  run 'github:nix-community/disko/latest#disko-install' -- \
  --flake ".#$HOST" \
  --disk main "$DISK"

cat <<EOF

Done. Reboot, remove the live USB, and the machine should boot '$HOST'.
You'll be prompted for the LUKS passphrase you set during install.
EOF
