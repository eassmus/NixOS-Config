{ config, pkgs, ... }: {
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "nodev";
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.useOSProber = true;
#  boot.loader.grub.backgroundColor = "#e9a6fd";
  boot.loader.grub.splashImage = ../files/mountain.jpg; 
  boot.loader.grub.splashMode = "stretch";
  boot.loader.grub.font = "${pkgs.jetbrains-mono}/share/fonts/truetype/JetBrainsMono-Bold.ttf";
  boot.loader.grub.fontSize = 32;
  boot.loader.timeout = -1;
}
