# Packages installed from nixpkgs-unstable rather than from the stable
# nixpkgs release that the rest of the system uses. A name in this list
# only affects machines that install that package.

{ nixpkgs-unstable }:

final: prev:
let
  unstable = import nixpkgs-unstable {
    system = final.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
prev.lib.genAttrs [
  # Gas City prerequisite (the `bd` CLI). Stable has 1.0.x; kept on
  # unstable so its database isn't opened by an older bd than wrote it.
  "beads"

  # Want 4.x; stable has 3.3.
  "bruno"

  # Releases weekly; stable nixpkgs lags badly.
  "claude-code"

  # Gas City's managed Dolt checks reject anything below 1.86.2. Stable
  # now meets that, but unstable is on 2.x; kept there so existing Dolt
  # data isn't opened by an older major version.
  "dolt"

  # Stable's 1.144.0 fails to build: its patchPhase rm's the pre-1.122
  # ripgrep path (@vscode/ripgrep/bin/rg); unstable has the
  # ripgrep-universal fix. Drop once stable gets it.
  "vscode"
] (name: unstable.${name})
