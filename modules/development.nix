{ pkgs, ... }:

{
  # docker
  virtualisation.docker.enable = true;

  environment.systemPackages = with pkgs; [
    # version control
    gitFull # includes gitk and git-gui
    tig
    gitui
    gh
    delta
    gitopolis

    # editors
    vim
    neovim

    # shell and terminal
    zsh
    zellij
    ghostty
    fzf

    # build tools
    gcc
    gnumake
    pkg-config
    openssl

    # languages and runtimes — managed via per-project nix flakes / direnv,
    # not a global tool-version manager.

    # search
    silver-searcher
    ripgrep

    # data
    sqlite
    sqlitebrowser
    jq

    # utilities
    curl
    wget
    tree
    pv
    dos2unix
    asciinema
    sloccount
    hashdeep

    # diff and merge
    kdiff3

    # per-process sandbox (used for risky commands / LLM agents — see
    # security-boundaries.md). Pairs with timabell/sandbox.
    bubblewrap
  ];
}
