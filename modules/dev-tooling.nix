{ pkgs, ... }:

# The development toolchain — language runtimes, compilers, package
# managers and build tools. VM ONLY: under the fleet's supply-chain
# policy all dev work happens inside the dev VM, never on bare metal.
# This module is imported only by the devvm; the rest of the toolchain
# (mise, node, IDEs, etc.) is added here in a later commit.

{
  environment.systemPackages = with pkgs; [
    azure-cli
    gcc
    gnumake
    pkg-config
  ];
}
