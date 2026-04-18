{
  description = "Tim's NixOS config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    disko.url = "github:nix-community/disko/latest";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs = { self, nixpkgs, disko, nixos-hardware, ... }: {
    nixosConfigurations.xps15 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.disko
        ./disko/xps15.nix
        ./hosts/xps15.nix
        nixos-hardware.nixosModules.dell-xps-15-9530
      ];
    };
  };
}
