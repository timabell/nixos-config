{ ... }:

# The shared module set every bare-metal fleet host imports. All hosts
# run a desktop OS (no headless servers), so desktop is part of the
# bare-metal base. A host adds only its own hardware (hosts/<name>.nix), disk
# layout, and nixos-hardware profile on top of this.

{
  imports = [
    ./base.nix
    ./user.nix
    ./all-hosts.nix
    ./containers.nix
    # ./python.nix  # EXPERIMENT: can bare metal live without python? (the devvm keeps it)
    ./desktop.nix
    ./networking.nix
    ./hardware.nix
    ./sandbox
  ];
}
