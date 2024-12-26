{ config, pkgs, lib , ... }:
let 
  newPkgs = import <nixos-24.11> { };
in {
  environment.systemPackages = with pkgs; [
    ly
    mpv 
    bat
    hwinfo
    libinput
    slack
    gtk3
    btop
    nvtopPackages.full
    htop
    gcc
    vscode
    cargo
    rustup
    rustc
    gnumake
    eza
    ripgrep
    vim
    newPkgs.neovim
    newPkgs.dotnetCorePackages.sdk_8_0_3xx
    fzf
    git
    gh
    gnumake
    lm_sensors
    brightnessctl
    cbonsai
    discord
    spotify
    github-desktop
    libsForQt5.qt5.qtquickcontrols2
    libsForQt5.qt5.qtgraphicaleffects
    libsForQt5.qt5.qtsvg
    neofetch
    tldr
    unzip
    openssl
    openssl.dev
    pkg-config
    wget
    xfce.thunar
    xdg-desktop-portal-gtk
    xdg-desktop-portal-wlr
    zip
    firefox
    tree
    lf
    zoxide
  ];

  environment.sessionVariables = rec {
    EDITOR = "nvim";
  };
}
