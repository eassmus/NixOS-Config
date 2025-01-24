{
  config,
  pkgs,
  lib,
  ...
}:
{
  services.udev.extraRules = builtins.readFile "${pkgs.openrgb}/lib/udev/rules.d/60-openrgb.rules";
  environment.systemPackages = with pkgs; [
    openrgb
  ];
}
