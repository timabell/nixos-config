{ pkgs, ... }:

# Minimal installable base for a fleet host: just enough to boot, get on
# the network, and `nixos-rebuild switch` to the full config. Used for the
# two-step install — the full host closure (desktop + apps) is too big to
# realise in a live USB's RAM-backed Nix store, so install this first
# (small), boot it, then switch to the full host config, which builds into
# the real on-disk store. Mirrors the devvm's devvm-base → devvm flow.

{
  imports = [
    ./base.nix
    ./user.nix
    ./networking.nix
  ];

  # git so you can fetch the flake for the step-two rebuild.
  environment.systemPackages = [ pkgs.git ];
}
