{ pkgs, lib, modulesPath, ... }:

# Minimal bootable NixOS image. The qcow2 built from this is small, so
# `cptofs` finishes in minutes rather than hours. Boot it, then run
# `nixos-rebuild switch --flake github:timabell/nixos-config#devvm`
# inside to apply the full devvm config — that path fetches store paths
# from cache.nixos.org over the network rather than re-running cptofs.

{
  imports = [
    "${toString modulesPath}/profiles/qemu-guest.nix"
    "${toString modulesPath}/virtualisation/disk-image.nix"
  ];

  boot.loader.timeout = 0;

  # Small disk at build time so cptofs/LKL can fit the ext4 metadata in
  # its ~100 MiB in-process memory budget. Resize the qcow2 to 80 GiB on
  # the host before first boot (`qemu-img resize`); growPartition +
  # autoResize from disk-image.nix expand the partition and filesystem
  # on first boot.
  virtualisation.diskSize = 4 * 1024;  # MiB
  image.baseName = "devvm-base";

  networking.hostName = "devvm";
  networking.useDHCP = lib.mkDefault true;

  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";
  console.keyMap = "uk";

  users.users.tim = {
    isNormalUser = true;
    description = "tim";
    extraGroups = [ "wheel" ];
    initialPassword = "changeme";
  };

  # Autologin on tty1 so you can immediately run nixos-rebuild without
  # configuring SSH keys first. SPICE shows tty1, so this Just Works.
  services.getty.autologinUser = "tim";

  # Optional second route in. Password auth so you don't need keys yet.
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = with pkgs; [
    git
    vim
  ];

  system.stateVersion = "25.05";
}
