# paths2html: same deal as gitopolis. Not in nixpkgs; pulled from its
# own flake input (the `nix` branch wraps the prebuilt static release
# binary) and exposed as `pkgs.paths2html`.

{ paths2html }:

final: prev: {
  paths2html = paths2html.packages.${final.stdenv.hostPlatform.system}.default;
}
