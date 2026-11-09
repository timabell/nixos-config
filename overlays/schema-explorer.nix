# schema-explorer — Go web app for browsing SQL database schemas.
# Not in nixpkgs. Build from source with buildGoModule. The binary
# loads `templates/`, `static/`, `config/` from CWD or, failing
# that, from the directory containing the executable
# (resources/resources.go uses os.Executable()), so we install the
# real binary into share/ alongside those dirs and wrap it in bin/.
# To bump: change `rev` to a new tag/commit, set `hash` and
# `vendorHash` to lib.fakeHash, rebuild, then paste the hashes
# nix prints back in.

final: prev: {
  schema-explorer = prev.buildGoModule rec {
    pname = "schema-explorer";
    version = "0.70";
    src = prev.fetchFromGitHub {
      owner = "timabell";
      repo = "schema-explorer";
      rev = "v${version}";
      hash = "sha256-ulNrz0nPQatxWP2wXULmR8g2bX4YHHxWkS5ioNN99J8=";
    };
    vendorHash = "sha256-9ygMN9LaaQ/DmlSYKkWNy16G71zv/QgduAA8TzbeBVs=";
    subPackages = [ "." ];
    # Upstream tests instantiate a DB driver and panic without one
    # (sse_test.go → reader.GetDbReader → "driver option missing").
    # Skip tests in the package build; this matches build.sh, which
    # only runs `go build`.
    doCheck = false;
    ldflags = [
      "-X github.com/timabell/schema-explorer/about.gitVersion=v${version}"
    ];
    nativeBuildInputs = [ prev.makeWrapper ];
    postInstall = ''
      mkdir -p $out/share/schema-explorer
      mv $out/bin/schema-explorer $out/share/schema-explorer/schemaexplorer
      cp -r templates static config $out/share/schema-explorer/
      makeWrapper $out/share/schema-explorer/schemaexplorer \
        $out/bin/schemaexplorer
    '';
  };
}
