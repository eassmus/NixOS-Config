{
  config,
  lib,
  pkgs,
  ...
}:

{
  services = {
    upower.enable = true;
    dbus.enable = true;
    picom.enable = true;
    openssh.enable = true;
    spice-vdagentd.enable = true;
    blueman.enable = true;
    printing.enable = true;
    asusd = {
      enable = true;
      enableUserService = true;
    };
    supergfxd.enable = true;
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
    xserver = {
      enable = false;
      xkb = {
        layout = "us";
        variant = "";
      };
    };

    displayManager = {
      ly = {
        enable = true;
      };
      sddm = {
        enable = false;
        wayland.enable = true;
        theme = "${import ./sddm-theme.nix {
          inherit lib;
          inherit pkgs;
        }}";
      };
    };
    gnome.gnome-keyring.enable = true;
  };
}
