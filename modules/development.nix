{ pkgs, ... }:

{
  # docker
  virtualisation.docker.enable = true;

  environment.systemPackages = with pkgs; [
    asciinema
    azure-cli
    bubblewrap
    curl
    delta
    dos2unix
    fzf
    gcc
    gh
    ghostty
    gitFull
    gitopolis
    gitui
    gnumake
    hashdeep
    jq
    kdiff3
    lazydocker
    lnav
    neovim
    openssl
    pkg-config
    pv
    ripgrep
    schema-explorer
    silver-searcher
    sloccount
    sqlite
    sqlitebrowser
    tig
    tree
    vim
    wget
    zellij
    zsh
  ];
}
