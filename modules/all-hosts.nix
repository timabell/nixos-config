{ pkgs, ... }:

# Tooling wanted on every nix machine — bare metal and the dev VM alike.
# This is the "safe enough for anywhere" surface: shell tooling plus a
# handful of self-contained utilities. Language build
# toolchains and package managers deliberately live in dev-tooling.nix
# (VM only), never here.

{
  environment.systemPackages = with pkgs; [
    asciinema
    btop
    bruno
    bubblewrap
    chromium
    curl
    delta
    disk-hog-backup
    dos2unix
    emote
    fastfetch
    file
    fzf
    gh
    ghostty
    gitFull
    gitopolis
    gitui
    hashdeep
    htop
    iotop
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
    lychee
    markdownlint-cli2
    meld
    nethogs
    sqlite
    sqlitebrowser
    tig
    tmux
    tree
    vscode
    vim
    wget
    xclip
    zellij
    zeal
    zola
    zsh
  ];

  programs.firefox = {
    enable = true;
    # Native window title bar instead of tabs drawn in it.
    preferences."browser.tabs.inTitlebar" = 0;
  };
}
