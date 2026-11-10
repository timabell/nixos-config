# Gitopolis isn't in nixpkgs; pull it from its own flake and expose
# as `pkgs.gitopolis` so modules/all-hosts.nix can list it alongside
# everything else.

{ gitopolis }:

final: prev: {
  gitopolis = gitopolis.packages.${final.stdenv.hostPlatform.system}.default;
}
