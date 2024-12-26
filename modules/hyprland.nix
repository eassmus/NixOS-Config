{ config, pkgs, ... }:

{
  programs.hyprland = {
    enable = true;
  };

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  environment.systemPackages = with pkgs; [
    hyprpaper
    hyprpicker
    hyprshade
    wev
    kitty
    hyprshot
    libnotify
    qt5.qtwayland
    qt6.qtwayland
    swayidle
    swaylock-effects
    wlogout
    wl-clipboard
    wofi
    waybar
  ];
}
