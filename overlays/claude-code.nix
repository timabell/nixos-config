# claude-code releases weekly and stable nixpkgs lags badly. The
# devvm already pulls it from unstable via devvm-from-unstable.nix; the
# bare-metal hosts run it too (sandboxed — see modules/sandbox), so
# they need the current release as well. This narrow overlay freshens
# only claude-code, leaving the rest of the host on stable.

{ nixpkgs-unstable }:

final: prev: {
  claude-code = (import nixpkgs-unstable {
    inherit (final) system;
    config.allowUnfree = true;
  }).claude-code;
}
