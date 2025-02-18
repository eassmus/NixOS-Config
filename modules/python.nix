{ lib, pkgs, ... }:
{
  environment.shellAliases = {
    venv = "virtualenv .venv";
  };

  environment.systemPackages = with pkgs; [
    (python3.withPackages (
      pkgs: with pkgs; [
        pip
        conda
        requests
        setuptools
        notebook
        jupyter
        ipykernel
        ipython
        jupyterlab
        virtualenv
      ]
    ))
    jupyter-all
    virtualenv
    poetry
  ];

}
