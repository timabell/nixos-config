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

  # slack is the only unfree desktop app; keep the allow next to it
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (pkgs.lib.getName pkg) [
      "slack"
    ];

  programs.thunderbird.enable = true;

  environment.systemPackages = with pkgs; [
    audacity
    cheese
    dia
    digikam
    firefox
    gimp
    inkscape
    kdePackages.okular
    keepassxc
    libreoffice
    meld
    obs-studio
    pavucontrol
    pdfarranger
    remmina
    screenkey
    shutter
    signal-desktop
    slack
    telegram-desktop
    vlc
    xclip
    zeal
  ];
}
