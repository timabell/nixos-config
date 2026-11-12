# Machines this flake builds (`nixosConfigurations.<name>`):
#
#   x15, cog            Bare-metal laptops. Built by `fleetHost` below from
#                       hosts/<name>.nix (hardware only) plus
#                       modules/bare-metal-hosts.nix and home/tim.nix.
#   x15-base, cog-base  Minimal installs of the same laptops, the first
#                       step of the two-step install (see `fleetHost`).
#   devvm               The development VM, the only machine with language
#                       toolchains. Built from `devvmModules` below:
#                       hosts/devvm.nix plus the shared and VM-only modules
#                       and home/tim-devvm.nix.
#   devvm-base          Minimal VM image, the first step of the devvm build.
#
# Packages wanted on every machine are listed in modules/all-hosts.nix. The
# overlays each machine uses are listed next to its modules below and
# defined in overlays/.

{
  description = "Tim's NixOS config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko/latest";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    gitopolis.url = "github:timabell/gitopolis/nix";
    gitopolis.inputs.nixpkgs.follows = "nixpkgs";
    disk-hog-backup.url = "github:timabell/disk-hog-backup/nix";
    disk-hog-backup.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, disko, nixos-hardware, home-manager, gitopolis, disk-hog-backup, ... }:
    let
      overlays = import ./overlays { inherit nixpkgs-unstable gitopolis disk-hog-backup; };

      devvmModules = [
        { nixpkgs.overlays = with overlays; [ fromUnstableOverlay gitopolisOverlay diskHogBackupOverlay lazydockerProfilesOverlay beadsTuiOverlay schemaExplorerOverlay ]; }
        ./hosts/devvm.nix
        ./modules/all-hosts.nix
        ./modules/containers.nix
        ./modules/dev-tooling.nix
        ./modules/python.nix
        ./modules/sandbox
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          # Rename pre-existing files out of the way instead of failing
          # activation. Without this, any home.file declaration that
          # collides with something VS Code/Firefox/etc. wrote on first
          # launch blocks the whole rebuild and leaves the VM in a
          # half-activated state.
          home-manager.backupFileExtension = "backup";
          home-manager.users.tim = import ./home/tim-devvm.nix;
        }
      ];

      # Every bare-metal fleet host yields two configs from one hardware
      # definition:
      #   .full — the complete desktop system
      #   .base — a minimal system for the two-step install. The full
      #           closure is too big to realise in a live USB's RAM-backed
      #           store, so install .base (small), boot it, then
      #           `nixos-rebuild switch` to .full, which builds into the
      #           real on-disk store. Mirrors the devvm-base -> devvm flow.
      fleetHost = { hostModule, hwModules ? [] }:
        let
          mk = extraModules: nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              disko.nixosModules.disko
              ./disko/common.nix
              hostModule
            ] ++ hwModules ++ extraModules;
          };
        in {
          full = mk [
            { nixpkgs.overlays = with overlays; [ fromUnstableOverlay gitopolisOverlay diskHogBackupOverlay lazydockerProfilesOverlay schemaExplorerOverlay cinnamonAppletsOverlay ]; }
            ./modules/bare-metal-hosts.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.tim.imports = [ ./home/tim.nix ./home/cinnamon.nix ];
            }
          ];
          base = mk [ ./modules/minimal.nix ];
        };

      x15Host = fleetHost {
        hostModule = ./hosts/x15.nix;
        hwModules = [ nixos-hardware.nixosModules.dell-xps-15-9530 ];
      };

      cogHost = fleetHost {
        hostModule = ./hosts/cog.nix;
        hwModules = [ nixos-hardware.nixosModules.framework-16-amd-ai-300-series ];
      };
    in {
      nixosConfigurations.x15 = x15Host.full;
      nixosConfigurations."x15-base" = x15Host.base;
      nixosConfigurations.cog = cogHost.full;
      nixosConfigurations."cog-base" = cogHost.base;

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
