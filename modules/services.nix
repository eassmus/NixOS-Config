{ config, lib, pkgs, ... }:

{
  imports = [
    <nixos-unstable/nixos/modules/services/display-managers/ly.nix>
  ];
  
  services = {
  	dbus.enable = true;
	picom.enable = true;
	openssh.enable = true;
        spice-vdagentd.enable = true;
	blueman.enable = true;
	printing.enable = true;
	avahi = {
	  enable = true;
	  nssmdns4 = true;
	  openFirewall = true;
	};
	xserver = {
		enable = true;
		xkb.layout = "us";
	};
	
	displayManager = {
	        ly = {
                	enable = false;
		};
		sddm.enable = true;
		sddm.theme = "${import ./sddm-theme.nix { inherit lib; inherit pkgs; }}";
	};
	gnome.gnome-keyring.enable = true;
  };
}
