{ pkgs, ... }:

# Tooling wanted on every nix machine — bare metal and the dev VM alike.
# This is the "safe enough for anywhere" surface: shell tooling plus a
# handful of self-contained utilities. Language build
# toolchains and package managers deliberately live in dev-tooling.nix
# (VM only), never here.

{
  environment.systemPackages = with pkgs; [
    asciinema
    bruno
    bubblewrap
    curl
    delta
    disk-hog-backup
    dos2unix
    emote
    firefox
    fzf
    gh
    ghostty
    gitFull
    gitopolis
    gitui
    hashdeep
    jq
    kdiff3
    lazydocker
    neovim
    openssl
    pavucontrol
    pv
    ripgrep
    schema-explorer
    silver-searcher
    loccount
    sqlite
    sqlitebrowser
    tig
    tree
    vim
    wget
    xclip
    zellij
    zsh
  ];
}
