{
  description = "My NixOS Config!";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    #nvim = {
    #  url = "path:/home/pulsar/Neovim-Config";
    #  inputs.nixpkgs.follows = "nixpkgs";
    #};
  };

  outputs =
    { self, nixpkgs, nixpkgs-unstable , ... }@inputs:
    let 
      # 1. Create a configured version of nixpkgs for your system
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config = {
          allowUnfree = true;
        };
      };
    in
    {
      nixosConfigurations.nixos-personal = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { 
          inherit inputs;
          pkgs-unstable = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true; # Allows unfree packages on unstable if needed
          };
        };
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
