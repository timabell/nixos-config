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

  outputs = { self, nixpkgs, disko, nixos-hardware, home-manager, ... }: {
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
  };
}
