{ pkgs, ... }:

{
  networking.hostName = "xps15";

  # live usb nixos on xps failed to find nvme without this:
  boot.kernelParams = [
    "nvme_core.default_ps_max_latency_us=0"
    "pcie_aspm=off"
  ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Cinnamon, Mint-style
  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.cinnamon.enable = true;

  # optional but practical
  services.displayManager.defaultSession = "cinnamon";

  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";

  users.users.tim = {
    isNormalUser = true;
    description = "tim";
    extraGroups = [ "wheel" "networkmanager" "audio" ];
    initialPassword = "changeme";
  };

  networking.networkmanager.enable = true;

  swapDevices = [
    {
      device = "/swap/swapfile";
      size = 16384;
    }
  ];

  # Audio - PulseAudio (familiar from Linux Mint)
  hardware.pulseaudio.enable = true;

  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    wget
    firefox
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  networking.firewall.enable = true;

  system.stateVersion = "25.05";
}
