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
      size = 32768; # = RAM, so the hibernate image always fits
    }
  ];

  # Hibernate to the swapfile. s2idle drains the battery flat in a couple
  # of days, and resuming from that left the EC throttling the CPU until a
  # full power-off. Offset is from
  # `btrfs inspect-internal map-swapfile -r /swap/swapfile`; redo it if the
  # swapfile is recreated (e.g. a size change).
  boot.resumeDevice = "/dev/mapper/cryptroot";
  boot.kernelParams = [ "resume_offset=194258176" ];
  systemd.sleep.settings.Sleep.HibernateDelaySec = "36h"; # hibernating costs a LUKS unlock; 36h so close-at-9am, open-at-10am-next-day stays a plain resume

  # No wake from keyboard/touchpad: keys pressed by the closing lid or in a bag can
  # wake it. Lid open and power button still wake. All Framework USB
  # modules, so swapped keyboard/numpad modules are covered too.
  services.udev.extraRules = let
    frameworkUsbVendor = "32ac";
    touchpadI2cDevice = "i2c-PIXA3854:00"; # PixArt touchpad, named from its firmware (ACPI) id
  in ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="${frameworkUsbVendor}", TEST=="power/wakeup", ATTR{power/wakeup}="disabled"
    ACTION=="add", SUBSYSTEM=="i2c", KERNEL=="${touchpadI2cDevice}", ATTR{power/wakeup}="disabled"
  '';

  # First install on 25.05; never change this for an existing machine.
  system.stateVersion = "25.05";
}
