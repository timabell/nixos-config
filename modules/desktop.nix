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

  # Non-FOSS packages have to be specifically allowed
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (pkgs.lib.getName pkg) [
      "slack"
      "obsidian"
    ];

  programs.thunderbird.enable = true;

  environment.systemPackages = with pkgs; [
    android-tools
    audacity
    cheese
    chromium
    clamtk
    dia
    digikam
    firefox
    gimp
    gpx-viewer
    inkscape
    k4dirstat
    kdePackages.okular
    keepassxc
    libreoffice
    meld
    obsidian
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
    vokoscreen
    x2goclient
    xclip
    zeal
  ];
}
