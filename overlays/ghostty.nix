# Stable's Ghostty 1.1.3 segfaults at startup because its libxev needs
# io_uring, which our hardened kernel disables (modules/hardware.nix);
# 1.3.1's libxev falls back to epoll. Narrow overlay like
# claude-code.nix — the rest of the host stays on stable.
# https://github.com/ghostty-org/ghostty/discussions/3267#discussioncomment-12283148

{ nixpkgs-unstable }:

final: prev: {
  ghostty = (import nixpkgs-unstable {
    inherit (final) system;
    config.allowUnfree = true;
  }).ghostty;
}
