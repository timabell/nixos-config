{ pkgs, ... }:

# Per-process bubblewrap sandbox. The `sandbox` command drops you into a
# bwrap shell with the given working tree(s) bound at ~/work, outbound
# network, and no access to the host home. Claude Code's own state
# (~/.claude and ~/.claude.json) is persisted in a dedicated host directory
# (~/.local/share/sandboxed-claude), separate from any real ~/.claude.
# Vendored from https://github.com/timabell/sandbox, which documents the
# threat model and the rationale for sandboxing a single risky command; see
# also security-boundaries.md.
#
# Claude Code is made available inside the sandbox by prepending its store
# path to the sandbox PATH (SANDBOX_EXTRA_PATH) — NOT by installing it on
# the host. So on bare-metal hosts `claude` runs only inside `sandbox`,
# never bare on the host. The devvm additionally installs claude-code on its
# PATH (modules/dev-tooling.nix), so there it also works outside the
# sandbox. claude-code tracks unstable, since it releases weekly: via
# claudeCodeOverlay in flake.nix on bare metal, via unstableOverlay on the
# devvm.
#
# Imported by modules/common.nix (bare metal) and devvmModules (devvm).

let
  sandbox = pkgs.writeShellApplication {
    name = "sandbox";
    runtimeInputs = with pkgs; [ bubblewrap coreutils bash ];
    text = ''
      export SANDBOX_BASHRC=${./sandbox.bashrc}
      export SANDBOX_EXTRA_PATH=${pkgs.claude-code}/bin
      exec bash ${./sandbox.sh} "$@"
    '';
  };
in
{
  environment.systemPackages = [ sandbox ];
}
