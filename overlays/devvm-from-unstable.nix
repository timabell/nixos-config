# Pulls specific packages from unstable when stable's version is too
# old. Applied only to the devvm — the bare-metal hosts stay on stable
# apart from their own one-package overlays (claude-code.nix, ghostty.nix).

{ nixpkgs-unstable }:

final: prev:
let
  unstable = import nixpkgs-unstable {
    inherit (final) system;
    config.allowUnfree = true;
  };
in {
  # mise 2025.5.3 (stable) compiles node from source on nixos (slow) instead of using the pre-built binaries
  mise = unstable.mise;
  # claude-code releases weekly; stable nixpkgs lags.
  claude-code = unstable.claude-code;
  # JetBrains IDEs ship quarterly; stable nixpkgs pins an old
  # minor. Pull the whole jetbrains set from unstable so any
  # IDE added in devvm.nix gets the current release.
  jetbrains = unstable.jetbrains;
  # Gas City prerequisites. Stable's dolt is 1.52.3; Gas City's
  # managed Dolt checks reject anything below 1.86.2, which is
  # exactly what unstable ships. beads (the `bd` CLI) isn't in
  # stable nixpkgs at all — unstable has 1.0.3.
  dolt = unstable.dolt;
  beads = unstable.beads;
}
