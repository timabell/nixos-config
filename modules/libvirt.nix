{ pkgs, ... }:

# Host side of the dev VM (devvm/README.md). Bare metal only.

{
  virtualisation.libvirtd = {
    enable = true;
    # devvm/define.sh attaches a virtiofs share; libvirt rejects qemu's old bundled virtiofsd.
    qemu.vhostUserPackages = [ pkgs.virtiofsd ];
  };
  programs.virt-manager.enable = true;

  # virsh/virt-viewer as non-root otherwise talk to qemu:///session, where the devvm isn't.
  environment.sessionVariables.LIBVIRT_DEFAULT_URI = "qemu:///system";

  # chattr, for devvm/create.sh to turn off btrfs CoW on the images dir.
  # Not on the system path otherwise since the fleet hosts have no ext4.
  environment.systemPackages = [ pkgs.e2fsprogs ];
}
