#!/usr/bin/env bash
# Move the flake to a new NixOS release, e.g. ./upgrade-nixos-release.sh 26.05
# Builds the current host, commits if that passes, but doesn't switch; see
# "Upgrading to a new NixOS release" in README.md.

set -euo pipefail

NEW="${1:-}"
if [[ ! $NEW =~ ^[0-9]{2}\.(05|11)$ ]]; then
  echo "usage: $0 <YY.05|YY.11>   e.g. $0 26.05" >&2
  exit 1
fi

# Read the current release out of this flake.nix line:
#   nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
# sed -n prints nothing by default; the s///p prints only the line it
# rewrites, replaced by the captured \(YY.MM\) group. Result: "25.05".
OLD="$(sed -n 's#.*NixOS/nixpkgs/nixos-\([0-9][0-9]\.[0-9][0-9]\)".*#\1#p' flake.nix)"
echo "==> flake.nix is currently on NixOS $OLD; upgrading to $NEW"

# Rewrite those two input URLs in place (sed -i), e.g. for 26.05:
#   github:NixOS/nixpkgs/nixos-25.05             -> nixos-26.05
#   github:nix-community/home-manager/release-25.05 -> release-26.05
# '#' is the s/// delimiter so the URL's slashes need no escaping. The
# trailing " anchors to the end of the URL, so nothing else (notably
# system.stateVersion / home.stateVersion, which must not change) matches.
echo "==> In flake.nix:"
echo "    nixpkgs input:      branch nixos-$OLD  -> nixos-$NEW"
echo "    home-manager input: branch release-$OLD -> release-$NEW"
echo "    (system.stateVersion / home.stateVersion left as they are)"
sed -i \
  -e "s#NixOS/nixpkgs/nixos-$OLD\"#NixOS/nixpkgs/nixos-$NEW\"#" \
  -e "s#home-manager/release-$OLD\"#home-manager/release-$NEW\"#" \
  flake.nix
git --no-pager diff flake.nix

echo "==> Pinning flake.lock to the latest commit on the new branches"
echo "+ nix flake update nixpkgs home-manager"
nix flake update nixpkgs home-manager

echo "==> Building .#$(hostname) (build only, nothing is switched)"
# Same build as `nixos-rebuild build`, minus the ./result symlink it leaves.
echo "+ nix build --no-link .#nixosConfigurations.$(hostname).config.system.build.toplevel"
nix build --no-link .#nixosConfigurations."$(hostname)".config.system.build.toplevel

if ! git diff --quiet flake.nix flake.lock; then
  echo "==> Committing flake.nix + flake.lock"
  echo "+ git commit --include flake.nix flake.lock --message \"Upgrade to NixOS $NEW\""
  git commit --include flake.nix flake.lock --message "Upgrade to NixOS $NEW"
fi

cat <<EOF

Build OK. Read the release notes before switching:
  https://nixos.org/manual/nixos/stable/release-notes#sec-release-$NEW

Then:
  ./update-current-host.sh
EOF
