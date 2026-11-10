# beads-tui (`bdt`) — TUI for the `bd` issue tracker. Not on PyPI
# or in nixpkgs; pinned to a specific commit on main. Built against
# unstable's python ecosystem because beads-tui needs textual >= 8
# and stable nixpkgs ships textual 3.2. To bump: change `rev` to a
# new commit, set `hash` to lib.fakeHash, rebuild, then paste the
# hash nix prints back in.

{ nixpkgs-unstable }:

final: prev:
let
  unstable = import nixpkgs-unstable {
    system = final.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in {
  beads-tui = unstable.python3.pkgs.buildPythonApplication {
    pname = "beads-tui";
    version = "0.2.16";
    pyproject = true;
    src = prev.fetchFromGitHub {
      owner = "gm2211";
      repo = "beads-tui";
      rev = "0f3c6345043a6047cd3d813ba41b2f87c6831226";
      hash = "sha256-R3qr/K4U6Y0+jBq+8BXF54C7wMv2eQ83aOzvDz2KR3w=";
    };
    build-system = [ unstable.python3.pkgs.setuptools unstable.python3.pkgs.setuptools-scm ];
    dependencies = [ unstable.python3.pkgs.textual ];
  };
}
