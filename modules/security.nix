{ pkgs, ... }:

{
  security.polkit.enable = true;
  security.pam.services.hyprlock = { };
  #security.pam.services.swaylock = { };
  #security.pam.services.swaylock.fprintAuth = false;
  security.pam.services.ly.enableGnomeKeyring = true;

  # lets the quickshell network popup poll per-process bandwidth without a
  # root prompt: nethogs needs raw-socket + /proc access to attribute traffic.
  security.wrappers.nethogs = {
    owner = "root";
    group = "root";
    capabilities = "cap_net_raw,cap_net_admin,cap_dac_read_search,cap_sys_ptrace+ep";
    source = "${pkgs.nethogs}/bin/nethogs";
  };
}
