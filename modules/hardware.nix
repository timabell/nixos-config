{ pkgs, ... }:

{
  # bluetooth
  hardware.bluetooth = {
    enable = true;
    settings.General.FastConnectable = true;
  };

  # firmware updates
  services.fwupd.enable = true;

  # printing (HP)
  services.printing = {
    enable = true;
    drivers = [ pkgs.hplip ];
  };

  # logitech device manager
  hardware.logitech.wireless.enable = true;

  # increase inotify limits for IDEs, syncthing, guard, etc.
  boot.kernel.sysctl = {
    "fs.inotify.max_user_instances" = 524288;
    "fs.inotify.max_user_watches" = 524288;
    "kernel.io_uring_disabled" = 1;
  };

  # gpg agent with pinentry for ssh sessions
  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-gtk2;
  };

  # power management
  services.power-profiles-daemon.enable = true;

  environment.systemPackages = with pkgs; [
    pciutils # lspci
    usbutils # lsusb
    htop
    btop
    iotop
    nethogs
    powertop
    neofetch
    smartmontools
    clamav
    v4l-utils
    ffmpeg
    mplayer
    guvcview
  ];
}
