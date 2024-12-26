{ lib, pkgs, ... }:
{
  environment.shellAliases = {
    venv = "virtualenv .venv";
  };
  
  environment.systemPackages = with pkgs; [
    (python3Full.withPackages (pkgs: with pkgs; [
      pip
      requests
      setuptools
      notebook
      jupyter
      ipykernel
      ipython
      jupyterlab
      virtualenv
    ]))
    jupyter-all
    virtualenv
    poetry
  ];

}
