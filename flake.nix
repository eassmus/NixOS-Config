{
  description = "My NixOS Config!";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    #nvim = {
    #  url = "path:/home/pulsar/Neovim-Config";
    #  inputs.nixpkgs.follows = "nixpkgs";
    #};
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let 
      # 1. Create a configured version of nixpkgs for your system
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config = {
          allowUnfree = true;
        };
      };
    in
    {
      nixosConfigurations.nixos-personal = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix
          #({ config, pkgs, ... }: {
          #  nixpkgs.overlays = [
          #    inputs.nvim.overlays.default
          #  ];
          #})
        ];
      };
    };
}
