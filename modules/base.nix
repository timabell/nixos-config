{ pkgs, ... }:

# System fundamentals shared by every bare-metal host. Deliberately
# impersonal — the default user lives in user.nix so forkers have one
# obvious place to change it. Per-host specifics (hostname, kernel
# modules, swap, and system.stateVersion) stay in hosts/<name>.nix.

{
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";

  # UEFI boot, common to every machine in the fleet.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # wifi/bluetooth firmware blobs
  hardware.firmware = [ pkgs.linux-firmware ];

  # login shell for the fleet
  programs.zsh.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
