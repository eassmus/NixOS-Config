{ ... }:

{
  services.automatic-timezoned.enable = true;
  services.geoclue2 = {
    enable = true;
    geoProviderUrl = "https://api.positon.xyz/v1/geolocate?key=test";
    submissionUrl = "https://api.positon.xyz/v2/geosubmit?key=test";
    submitData = false;
  };
  services.localtimed.enable = true;

  time.hardwareClockInLocalTime = true;
}
