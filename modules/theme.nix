{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    gnome.adwaita-icon-theme # default gnome cursors
    glib
    gsettings-desktop-schemas
    nwg-look
  ];
}
