{ config, lib, pkgs-unstable, ... }:

# Goodix 27c6:521d fingerprint reader. Upstream libfprint doesn't support it, so this
# builds the community goodixtls fork. One-time setup before enrolling:
#   sudo systemctl stop fprintd && sudo goodix-521d-flash && fprintd-enroll
# (the flash writes the key the driver expects; Windows sets a different one, so
# fingerprint stops working there)
# Based on https://github.com/barsikus007/config, see also nixpkgs#424877.
let
  p = pkgs-unstable;

  libfprint-521d = p.stdenv.mkDerivation {
    pname = "libfprint-goodixtls-27c6-521d";
    version = "1.94.9";

    src = p.fetchFromGitHub {
      owner = "barsikus007";
      repo = "libfprint";
      rev = "2ff5f5c0eebe617302ad114e7d71d3add686ca36"; # merge/upstream-1.94.9
      hash = "sha256-Zov/PfvKBfnoRUyUGsOsofrTt80kHq0eKCKlRXyvnio=";
    };

    nativeBuildInputs = with p; [ meson ninja pkg-config cmake gtk-doc doctest ];
    buildInputs = with p; [ glib gusb gobject-introspection pixman openssl libgudev libfprint cairo ];

    mesonBuildType = "release";
    mesonFlags = [
      "-Dintrospection=false"
      "-Ddoc=false"
      "-Dinstalled-tests=false"
      "-Dudev_rules_dir=${placeholder "out"}/lib/udev/rules.d"
      "-Dudev_hwdb_dir=${placeholder "out"}/lib/udev/hwdb.d"
    ];
    strictDeps = true;

    # https://gcc.gnu.org/gcc-14/porting_to.html#incompatible-pointer-types
    env.NIX_CFLAGS_COMPILE = "-Wno-error=incompatible-pointer-types";
  };

  # flashes the sensor's firmware + pre-shared key (goodix-fp-dump's run_521d.py)
  goodix-521d-flash =
    let
      src = p.applyPatches {
        name = "goodix-fp-dump";
        src = p.fetchFromGitHub {
          owner = "goodix-fp-linux-dev";
          repo = "goodix-fp-dump";
          rev = "cc43bb3b3154a0bccc0412ae024013c7e1923139";
          hash = "sha256-AVq2PZe0iv9Mh8+XRr/vbZsbvDIrPKD90Xdu9lXs8p0=";
          fetchSubmodules = true;
        };
        # skip the "len(otp) < 64" check, which trips on this sensor
        postPatch = "sed --in-place '133,134s/^/#/' driver_52xd.py";
      };
      python = p.python3.withPackages (ps: with ps; [
        pyusb crcmod python-periphery spidev pycryptodome crccheck
      ]);
    in
    p.writeShellScriptBin "goodix-521d-flash" ''
      cd ${src}
      PATH="$PATH:${p.openssl}/bin" exec ${python}/bin/python run_521d.py
    '';

  usbId = { vendor = "27c6"; product = "521d"; };
in
{
  services.fprintd = {
    enable = true;
    package = p.fprintd.override { libfprint = libfprint-521d; };
  };

  environment.systemPackages = [ goodix-521d-flash ];

  # powertop auto-tune would autosuspend the sensor; the goodixtls driver doesn't
  # handle suspend/resume, so keep it awake (appends to hardware.nix's postStart)
  powerManagement.powertop.postStart = ''
    for d in /sys/bus/usb/devices/*; do
      if [ "$(cat $d/idVendor 2>/dev/null)" = ${usbId.vendor} ] &&
        [ "$(cat $d/idProduct)" = ${usbId.product} ]; then echo on > $d/power/control; fi
    done
  '';

  # same reason for system sleep: the device is gone after resume and fprintd keeps a
  # stale claim, so lock screens hang on verify. Type=dbus restarts it on first use.
  powerManagement.powerDownCommands = ''
    ${lib.getExe' config.systemd.package "systemctl"} stop fprintd.service || true
  '';

  # PAM fingerprint in hyprlock blocks password entry until the finger times out;
  # hyprlock has its own fingerprint support to enable once enrollment works
  security.pam.services.hyprlock.fprintAuth = false;
}
