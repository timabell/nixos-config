# md5-tools: same deal as gitopolis. Not in nixpkgs; pulled from the
# timabell fork's flake input (the `nix` branch wraps the prebuilt
# musl release binaries) and exposed as `pkgs.md5-tools`.

{ md5-tools }:

final: prev: {
  md5-tools = md5-tools.packages.${final.stdenv.hostPlatform.system}.default;
}
