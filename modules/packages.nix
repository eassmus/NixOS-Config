{
  config,
  pkgs,
  pkgs-unstable,
  lib,
  inputs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    #(llama-cpp.override { cudaSupport = true; })

    #Utility
    brightnessctl
    glow
    wl-kbptr
    wlrctl

    #Desktop
    pkgs-unstable.quickshell
    quickshell
    hypridle

    #Rust
    rustc
    cargo
    rustup

    #Nix
    inputs.nix-graph.packages.${pkgs.stdenv.hostPlatform.system}.nix-graph
    nixfmt
    nixd

    #Editors
    lua5_1
    lua51Packages.luarocks
    inputs.claude-code.packages.${pkgs.system}.default
    mono
    unityhub

    #Desktop Apps
    brave

    #Network
    openconnect
    networkmanager-openconnect

    texliveMedium
    zotero
    poppler-utils
    psmisc
    omnisharp-roslyn
    csharp-ls
    octave
    zoxide
    hotspot
    uutils-coreutils-noprefix
    timg
    feh
    qrrs
    jq
    obs-studio
    gdb
    asusctl
    eza
    tokei
    obsidian
    trash-cli
    vlc
    dua
    dust
    hyperfine
    bat
    fd
    valgrind
    cava
    ripgrep
    ffmpeg
    ffmpegthumbnailer
    gimp
    slack
    nodejs
    mpv
    bat
    hwinfo
    libinput
    nethogs
    playerctl
    gtk3
    btop
    nvtopPackages.full
    htop
    gcc13
    vscode
    gnumake
    vim
    neovide
    neovim
    fastfetch
    dotnetCorePackages.sdk_11_0-bin
    fzf
    git
    gh
    gnumake
    lm_sensors
    brightnessctl
    cbonsai
    discord
    spotify
    libsForQt5.qt5.qtquickcontrols2
    libsForQt5.qt5.qtgraphicaleffects
    libsForQt5.qt5.qtsvg
    tldr
    unzip
    openssl
    openssl.dev
    pkg-config
    wget
    xdg-desktop-portal-gtk
    xdg-desktop-portal-wlr
    zip
    firefox
    ripgrep
    basedpyright
    typescript-language-server
    lua-language-server
    rust-analyzer
    clang-tools
    luaformatter
    xleak
  ];

  environment.sessionVariables = rec {
    EDITOR = "nvim";
  };
}
