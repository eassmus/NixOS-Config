{
  config,
  pkgs,
  lib,
  ...
}:
{

  environment.systemPackages = with pkgs; [
    #(llama-cpp.override { cudaSupport = true; })
    hotspot
    timg
    feh
    qrrs
    jq
    obs-studio
    asusctl
    bc
    trash-cli
    vlc
    valgrind
    cava
    ffmpeg
    ffmpegthumbnailer
    mathpix-snipping-tool
    gimp
    slack
    nodejs
    nixfmt-rfc-style
    mpv
    bat
    hwinfo
    libinput
    playerctl
    gtk3
    btop
    nvtopPackages.full
    htop
    gcc
    vscode
    cargo
    rustup
    gnumake
    vim
    neovim
    dotnetCorePackages.sdk_8_0_3xx
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
    #xfce.thunar
    xdg-desktop-portal-gtk
    xdg-desktop-portal-wlr
    zip
    firefox
    ripgrep
  ];

  environment.sessionVariables = rec {
    EDITOR = "nvim";
  };
}
