{ pkgs, ... }:

{
  security.polkit.enable = true;
  security.pam.services.swaylock = { };
  security.pam.services.swaylock.fprintAuth = false;
  security.pam.services.ly.enableGnomeKeyring = true;
}
