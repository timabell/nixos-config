{ pkgs, ... }:

# The development toolchain — language runtimes, compilers, package
# managers, IDEs and build tools. VM ONLY: under the fleet's
# supply-chain policy all dev work happens inside the dev VM, never on
# bare metal. Imported only by the devvm.

{
  # IDEs aren't free-licensed
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (pkgs.lib.getName pkg) [
      "rider"
      "webstorm"
      "vscode"
    ];

  environment.systemPackages = with pkgs; [
    # build toolchain
    azure-cli
    gcc
    gnumake
    pkg-config

    # IDEs
    jetbrains.rider
    jetbrains.webstorm
    vscode

    # node + npm. Per-project versions via a flake.nix + direnv inside
    # individual repos.
    nodejs_24

    # direnv + nix-direnv: per-project dev shells via flake.nix +
    # `.envrc` containing `use flake`. VM-only because auto-loading
    # repo-local config (even with `direnv allow`) is one more
    # supply-chain edge we don't want on the primary host.
    direnv
    nix-direnv

    # mise — per-project runtime version manager. Hybrid model: nix
    # provides system-level node/claude/etc., mise provides
    # exact-version-match for client repos with a .tool-versions or
    # .nvmrc. VM-only for supply-chain reasons; mise pulls upstream
    # prebuilts and we don't want those touching the host. python (for
    # mise plugins) comes from modules/python.nix.
    mise
    pipx          # isolated-venv installer for Python CLIs
    beads-tui     # `bdt` — TUI for the bd issue tracker (overlay in flake.nix)

    # Anthropic's Claude Code CLI. VM-only — agents run inside the VM,
    # never on the host. Pulled from unstable via overlay in flake.nix
    # so we get current releases (claude-code updates weekly).
    claude-code

    # .env password manager https://github.com/gopasspw/gopass
    gopass

    # Gas City prerequisites — https://github.com/gastownhall/gascity
    # (docs/getting-started/installation.md#prerequisites). VM-only:
    # Gas City and its agents run inside the VM. The remaining prereqs
    # are already covered — jq and git come from modules/cli.nix,
    # gnumake is above, and flock ships in util-linux, which is in
    # NixOS's default system packages.
    tmux
    dolt    # 1.86.2+ required; pinned to unstable via flake.nix overlay
    beads   # the `bd` CLI; unstable-only, see flake.nix overlay
    go      # source builds of Gas City (1.25+)
  ];
}
