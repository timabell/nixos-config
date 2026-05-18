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

      devvmModules = [
        { nixpkgs.overlays = [ unstableOverlay gitopolisOverlay ]; }
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
          home-manager.users.tim = { lib, ... }: {
            imports = [ ./home/tim.nix ];
            # No GPG keys in the VM — keys live on the host.
            programs.git.extraConfig.commit.gpgsign = lib.mkForce false;
            # Per-project dev shells via direnv + nix-direnv. VM-only;
            # see hosts/devvm.nix for reasoning.
            programs.direnv.enable = true;
            programs.direnv.nix-direnv.enable = true;
            # Per-project runtime versions via mise. VM-only.
            programs.mise = {
              enable = true;
              enableZshIntegration = true;
              globalConfig = {
                tools.adr-tools = "3.0.0";
                settings = {
                  # Read .nvmrc / global.json / .ruby-version etc. so
                  # legacy repos work without an explicit .mise.toml.
                  idiomatic_version_file_enable_tools = [ "node" "dotnet" "ruby" ];
                  not_found_auto_install = false;
                  # Force prebuilt node tarballs instead of source build.
                  # mise's default in 2025.5.3 (nixpkgs 25.05) compiles V8
                  # from source which is ~10× slower than the prebuilt.
                  node.compile = false;
                };
              };
            };
            # Re-evaluate DOTNET_ROOT on every cd so dotnet-tools find
            # whichever .NET version mise has provisioned for the project.
            programs.zsh.initContent = lib.mkAfter ''
              function _update_dotnet_root() {
                export DOTNET_ROOT=$(mise where dotnet-core 2>/dev/null)
              }
              add-zsh-hook precmd _update_dotnet_root
            '';
            # VS Code on XFCE auto-picks a secret-storage backend at
            # startup and hangs when the chosen one (KWallet, in our
            # case — pulled in via kdiff3's KDE deps) tries to unlock a
            # GPG-encrypted wallet we don't have keys for. "basic"
            # writes secrets in plain text under ~/.config/Code. That's
            # acceptable here: the VM is disposable, sandboxed, and
            # holds no GPG keys (see commit.gpgsign override above) —
            # the threat of plaintext VS Code tokens on the VM disk
            # isn't different in kind from the VM itself.
            home.file.".vscode/argv.json".text = ''
              {
                "password-store": "basic"
              }
            '';
          };
        }
      ];
    in {
      nixosConfigurations.x15 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          { nixpkgs.overlays = [ gitopolisOverlay ]; }
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
