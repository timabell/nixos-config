# disk-hog-backup: same deal as gitopolis — not in nixpkgs, pulled from
# its own flake input (the `nix` branch wraps the prebuilt musl release
# binary) and exposed as `pkgs.disk-hog-backup` for modules/all-hosts.nix.

{ disk-hog-backup }:

final: prev: {
  disk-hog-backup = disk-hog-backup.packages.${final.stdenv.hostPlatform.system}.default;
}
