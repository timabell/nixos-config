#!/bin/sh
nix flake update nixpkgs
nix flake update nixpkgs-unstable
nix flake update gitopolis
git commit --include flake.lock --message "Updates - flake.lock "
