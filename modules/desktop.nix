{ pkgs, ... }:

{
  # Cinnamon desktop environment, Mint-style
  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.cinnamon.enable = true;
  services.displayManager.defaultSession = "cinnamon";

  # UK keyboard layout
  services.xserver.xkb.layout = "gb";
  console.keyMap = "uk";

  # blue light filter is managed per-user via home-manager (services.redshift)

  # flatpak for anything not well-packaged in nixpkgs
  services.flatpak.enable = true;

  # fonts
  fonts.packages = with pkgs; [
    jetbrains-mono
  ];

  # sound (pipewire is the NixOS 25.05 default)
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    # desktop applications
    firefox
    keepassxc
    libreoffice
    kdePackages.okular
    pdfarranger
    gimp
    dia
    meld
    remmina
    zeal
    digikam
    obs-studio
    audacity
    vlc
    cheese
    inkscape
    signal-desktop
    slack
    telegram-desktop
    logseq

    # desktop utilities
    parcellite
    xclip
    pavucontrol
    screenkey
  ];
}
