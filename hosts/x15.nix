{ ... }:

{
  networking.hostName = "x15";

  # live usb nixos failed to find nvme without this:
  boot.kernelParams = [
    "nvme_core.default_ps_max_latency_us=0"
    "pcie_aspm=off"
  ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" ];

  swapDevices = [
    {
      device = "/swap/swapfile";
      size = 16384;
    }
  ];

  # First install was on 25.05; never change this for an existing machine.
  system.stateVersion = "25.05";
}
