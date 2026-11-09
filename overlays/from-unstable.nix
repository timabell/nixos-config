# Packages installed from nixpkgs-unstable rather than from the stable
# nixpkgs release that the rest of the system uses. A name in this list
# only affects machines that install that package.

{ nixpkgs-unstable }:

final: prev:
let
  unstable = import nixpkgs-unstable {
    inherit (final) system;
    config.allowUnfree = true;
  };
in
prev.lib.genAttrs [
  # Gas City prerequisite (the `bd` CLI); not in stable nixpkgs at all.
  "beads"

  # OpenCollection YAML collections need 3.0+; stable has 2.x.
  "bruno"

  # Releases weekly; stable nixpkgs lags badly.
  "claude-code"

  # Gas City's managed Dolt checks reject anything below 1.86.2; stable
  # has 1.52.3.
  "dolt"

  # Stable's 1.1.3 segfaults at startup because its libxev needs io_uring,
  # which the bare-metal hardened kernel disables (modules/hardware.nix);
  # 1.3.1's libxev falls back to epoll.
  # https://github.com/ghostty-org/ghostty/discussions/3267#discussioncomment-12283148
  "ghostty"

  # IDEs ship quarterly; stable pins an old minor. The whole set, so any
  # IDE added to dev-tooling.nix gets the current release.
  "jetbrains"

  # Stable's 2025.5.3 compiles node from source on nixos (slow) instead
  # of using the pre-built binaries.
  "mise"
] (name: unstable.${name})
