{ pkgs, ... }:

{
  # docker
  virtualisation.docker.enable = true;

  environment.systemPackages = with pkgs; [
    # version control
    git
    gitk
    git-gui
    tig
    gitui
    gh
    git-delta

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

    # languages and runtimes (version-pinned runtimes managed by mise)
    mise

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
  ];
}
