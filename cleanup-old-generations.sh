#!/usr/bin/env bash
# Free disk space: delete system and user generations older than 90 days,
# garbage-collect the store, and drop their boot menu entries. See
# "Freeing disk space" in README.md.

set -euo pipefail

echo "==> Store size before"
echo "+ du -sh /nix/store"
du -sh /nix/store

echo "==> Deleting system generations older than 90 days, then collecting garbage"
echo "+ sudo nix-collect-garbage --delete-older-than 90d"
sudo nix-collect-garbage --delete-older-than 90d

echo "==> Deleting your user (home-manager) generations older than 90 days"
echo "+ nix-collect-garbage --delete-older-than 90d"
nix-collect-garbage --delete-older-than 90d

echo "==> Rewriting boot menu entries so deleted generations disappear"
echo "+ sudo nixos-rebuild boot --flake .#$(hostname)"
sudo nixos-rebuild boot --flake .#"$(hostname)"

echo "==> Store size after"
echo "+ du -sh /nix/store"
du -sh /nix/store
