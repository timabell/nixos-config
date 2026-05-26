{ lib, ... }:

{
  imports = [ ./tim.nix ];

  # No GPG keys in the VM — keys live on the host.
  programs.git.extraConfig.commit.gpgsign = lib.mkForce false;

  # Per-project dev shells via direnv + nix-direnv. VM-only;
  # see hosts/devvm.nix for reasoning.
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

  # Per-project runtime versions via mise. VM-only.
  programs.mise = {
    enable = true;
    enableZshIntegration = true;
    globalConfig = {
      tools.adr-tools = "3.0.0";
      settings = {
        # Read .nvmrc / global.json / .ruby-version etc. so
        # legacy repos work without an explicit .mise.toml.
        idiomatic_version_file_enable_tools = [ "node" "dotnet" "ruby" ];
        not_found_auto_install = false;
        # Force prebuilt node tarballs instead of source build.
        # mise's default in 2025.5.3 (nixpkgs 25.05) compiles V8
        # from source which is ~10× slower than the prebuilt.
        node.compile = false;
      };
    };
  };

  # Re-evaluate DOTNET_ROOT on every cd so dotnet-tools find
  # whichever .NET version mise has provisioned for the project.
  programs.zsh.initContent = lib.mkAfter ''
    function _update_dotnet_root() {
      export DOTNET_ROOT=$(mise where dotnet-core 2>/dev/null)
    }
    add-zsh-hook precmd _update_dotnet_root
  '';

  # VS Code on XFCE auto-picks a secret-storage backend at
  # startup and hangs when the chosen one (KWallet, in our
  # case — pulled in via kdiff3's KDE deps) tries to unlock a
  # GPG-encrypted wallet we don't have keys for. "basic"
  # writes secrets in plain text under ~/.config/Code. That's
  # acceptable here: the VM is disposable, sandboxed, and
  # holds no GPG keys (see commit.gpgsign override above) —
  # the threat of plaintext VS Code tokens on the VM disk
  # isn't different in kind from the VM itself.
  home.file.".vscode/argv.json".text = ''
    {
      "password-store": "basic"
    }
  '';
}
