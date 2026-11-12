{ pkgs, ... }:

{
  # Cinnamon desktop environment, Mint-style
  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.cinnamon.enable = true;
  services.displayManager.defaultSession = "cinnamon";
  environment.cinnamon.excludePackages = [ pkgs.onboard ];
  # sysmonitor@orcus needs the GTop typelib, which Cinnamon's wrapper lacks.
  services.xserver.desktopManager.cinnamon.sessionPath = [ pkgs.libgtop ];

  # UK keyboard layout
  services.xserver.xkb.layout = "gb";
  console.keyMap = "uk";

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
      "vscode"
    ];

  programs.thunderbird.enable = true;

  environment.systemPackages = with pkgs; [
    android-tools
    audacity
    cheese
    chromium
    cinnamon-applets
    clamtk
    dia
    digikam
    gimp
    gnome-system-monitor
    gpxsee
    inkscape
    qdirstat
    kdePackages.okular
    kdePackages.kdenlive
    keepassxc
    libreoffice
    maestral
    meld
    obsidian
    obs-studio
    pdfarranger
    remmina
    screenkey
    shutter
    signal-desktop
    slack
    telegram-desktop
    vlc
    vokoscreen-ng
    vscode
    x2goclient
    zeal
  ];
}
