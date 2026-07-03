{ ... }:

# Framework Laptop 16 (AMD). Hardware quirks come from the nixos-hardware
# framework-16-amd-ai-300-series profile wired in via flake.nix (base
# profile, not the -nvidia variant, since there's no discrete GPU); this
# file carries only what's specific to this machine.

{
  networking.hostName = "cog";

  # Boot + LUKS unlock: NVMe for the disk, usbhid so the built-in
  # keyboard can type the passphrase. If nixos-generate-config on the
  # real hardware suggests more, add them here.
  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "thunderbolt" "usb_storage" "usbhid" "sd_mod" ];
  boot.kernelModules = [ "kvm-amd" ];

  swapDevices = [
    {
      device = "/swap/swapfile";
      size = 16384;
    }
  ];

  # First install on 25.05; never change this for an existing machine.
  system.stateVersion = "25.05";
}
