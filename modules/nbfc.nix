# nbfc.nix
{
  config,
  inputs,
  pkgs,
  ...
}: let
  myUser = "pulsar"; #adjust this to your username
  command = "bin/nbfc_service --config-file '/home/${myUser}/.config/nbfc.json'";
in {
  environment.systemPackages = with pkgs; [
    nbfc-linux
  ];
  systemd.services.nbfc_service = {
    enable = true;
    description = "NoteBook FanControl service";
    serviceConfig.Type = "simple";
    path = [pkgs.kmod];
    script = "${pkgs.nbfc-linux.packages}/${command}";
   
    wantedBy = ["multi-user.target"];
  };
}
