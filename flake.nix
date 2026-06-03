{
  description = "Tim's NixOS config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko/latest";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    gitopolis.url = "github:timabell/gitopolis/nix";
    gitopolis.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, disko, nixos-hardware, home-manager, gitopolis, ... }:
    let
      # Gitopolis isn't in nixpkgs; pull it from its own flake and expose
      # as `pkgs.gitopolis` so modules/development.nix can list it
      # alongside everything else.
      gitopolisOverlay = final: prev: {
        gitopolis = gitopolis.packages.${final.system}.default;
      };
      # Overlay that pulls specific packages from unstable when stable's
      # version is too old. Applied only to the devvm — keep x15 stable.
      unstableOverlay = final: prev:
        let
          unstable = import nixpkgs-unstable {
            inherit (final) system;
            config.allowUnfree = true;
          };
        in {
          # mise 2025.5.3 (stable) compiles node from source on nixos (slow) instead of using the pre-built binaries
          mise = unstable.mise;
          # claude-code releases weekly; stable nixpkgs lags.
          claude-code = unstable.claude-code;
          # JetBrains IDEs ship quarterly; stable nixpkgs pins an old
          # minor. Pull the whole jetbrains set from unstable so any
          # IDE added in devvm.nix gets the current release.
          jetbrains = unstable.jetbrains;
          # Gas City prerequisites. Stable's dolt is 1.52.3; Gas City's
          # managed Dolt checks reject anything below 1.86.2, which is
          # exactly what unstable ships. beads (the `bd` CLI) isn't in
          # stable nixpkgs at all — unstable has 1.0.3.
          dolt = unstable.dolt;
          beads = unstable.beads;
        };

      # Upstream lazydocker doesn't understand docker-compose profiles
      # (https://github.com/jesseduffield/lazydocker/issues/423). Pulled from
      # timabell/lazydocker @ feat/docker-compose-profiles, a from-scratch
      # implementation on top of master (see that repo's
      # docs/adr/0001-docker-compose-profile-support.md). Upstream
      # vendorHash is null (deps are vendored), so overriding src is enough.
      lazydockerProfilesOverlay = final: prev: {
        lazydocker = prev.lazydocker.overrideAttrs (_: {
          src = prev.fetchFromGitHub {
            owner = "timabell";
            repo = "lazydocker";
            rev = "1f035a8d6d318c84e8d7ec47cb3d9ba3a1b5f961";
            hash = "sha256-gxxNYclOc7KvZwt54Y0S4sUjq3xNxzuZdtRkmzTgWuk=";
          };
        });
      };

      # beads-tui (`bdt`) — TUI for the `bd` issue tracker. Not on PyPI
      # or in nixpkgs; pinned to a specific commit on main. Built against
      # unstable's python ecosystem because beads-tui needs textual >= 8
      # and stable nixpkgs ships textual 3.2. To bump: change `rev` to a
      # new commit, set `hash` to lib.fakeHash, rebuild, then paste the
      # hash nix prints back in.
      beadsTuiOverlay = final: prev:
        let
          unstable = import nixpkgs-unstable {
            inherit (final) system;
            config.allowUnfree = true;
          };
        in {
          beads-tui = unstable.python3.pkgs.buildPythonApplication {
            pname = "beads-tui";
            version = "0.2.16";
            pyproject = true;
            src = prev.fetchFromGitHub {
              owner = "gm2211";
              repo = "beads-tui";
              rev = "0f3c6345043a6047cd3d813ba41b2f87c6831226";
              hash = "sha256-R3qr/K4U6Y0+jBq+8BXF54C7wMv2eQ83aOzvDz2KR3w=";
            };
            build-system = [ unstable.python3.pkgs.setuptools unstable.python3.pkgs.setuptools-scm ];
            dependencies = [ unstable.python3.pkgs.textual ];
          };
        };

      devvmModules = [
        { nixpkgs.overlays = [ unstableOverlay gitopolisOverlay lazydockerProfilesOverlay beadsTuiOverlay ]; }
        ./hosts/devvm.nix
        ./modules/development.nix
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
    in {
      nixosConfigurations.x15 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          { nixpkgs.overlays = [ gitopolisOverlay lazydockerProfilesOverlay ]; }
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
