{ config, pkgs, ... }:

{
  nix.settings = {
    substituters = [ "https://cache.nixos-cuda.org" ];
    trusted-public-keys = [ "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M=" ];
  };

  environment.systemPackages = with pkgs; [
    pciutils
    file

    gnumake

    cudatoolkit
    cudaPackages.cudnn
  ];
}
