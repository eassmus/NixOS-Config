{ config, pkgs, ... }:

{
  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  # `powertop --auto-tune` at boot: runtime PM for audio codec, PCIe links, USB, etc.
  powerManagement.powertop = {
    enable = true;
    # auto-tune lets USB devices autosuspend after 2s, which lags the first
    # keypress/mouse move and stutters Bluetooth; keep HID (class 03) and
    # Bluetooth (class e0) devices awake
    postStart = ''
      for d in /sys/bus/usb/devices/*; do
        # if, not &&: a trailing non-match would make the script exit non-zero
        if grep -qxE '03|e0' $d/*/bInterfaceClass 2>/dev/null; then echo on > $d/power/control; fi
      done
    '';
  };
}
