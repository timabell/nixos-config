{
  description = "Tim's NixOS config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    disko.url = "github:nix-community/disko/latest";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, nixos-hardware, home-manager, ... }:
    let
      devvmModules = [
        ./hosts/devvm.nix
        ./modules/development.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.tim = { lib, ... }: {
            imports = [ ./home/tim.nix ];
            # No GPG keys in the VM — keys live on the host.
            programs.git.extraConfig.commit.gpgsign = lib.mkForce false;
          };
        }
      ];
    in {
      nixosConfigurations.x15 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          ./disko/x15.nix
          ./hosts/x15.nix
          ./modules/desktop.nix
          ./modules/development.nix
          ./modules/networking.nix
          ./modules/hardware.nix
          nixos-hardware.nixosModules.dell-xps-15-9530
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.tim = import ./home/tim.nix;
          }
        ];
      };

      # Bare-bones bootable image. Build this first — small closure, fast
      # cptofs. Boot it, then in-place switch to the full devvm config.
      nixosConfigurations.devvm-base = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./hosts/devvm-base.nix ];
      };

      # Full devvm config. Used in-place inside the running base VM:
      #   sudo nixos-rebuild switch --flake github:timabell/nixos-config#devvm
      # Building it as a fresh qcow2 is also possible (.#devvm) but slow.
      nixosConfigurations.devvm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = devvmModules;
      };

      # `nix build .#devvm-base` → result/devvm-base.qcow2 (the fast path)
      packages.x86_64-linux.devvm-base =
        self.nixosConfigurations.devvm-base.config.system.build.image;

      # `nix build .#devvm` → result/devvm.qcow2 (slow; only for fresh disks)
      packages.x86_64-linux.devvm =
        self.nixosConfigurations.devvm.config.system.build.image;
    };
}
