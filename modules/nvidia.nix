{
  pkgs,
  config,
  libs,
  ...
}:

let
  # run one app on the dGPU; also undoes the "AMD only" EGL/Vulkan hiding from
  # hypr/env.lua, which NixOS's built-in offload command wouldn't
  nvidia-offload = pkgs.writeShellScriptBin "nvidia-offload" ''
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __VK_LAYER_NV_optimus=NVIDIA_only
    export __EGL_VENDOR_LIBRARY_FILENAMES=/run/opengl-driver/share/glvnd/egl_vendor.d/10_nvidia.json
    unset VK_DRIVER_FILES
    exec "$@"
  '';
in
{
  # Enable OpenGL
  hardware.graphics.enable = true;

  environment.systemPackages = [ nvidia-offload ];

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  boot.kernelParams = [ 
    "nvidia.NVreg_DynamicPowerManagement=0x02"
    "nvidia.NVreg_DynamicPowerManagementVideoMemoryThreshold=0"
    "nvidia_drm.fbdev=0" 
  ];

  services.udev.extraRules = ''
    # Use add|bind to ensure the rule hits regardless of module load timing
    ACTION=="add|bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{power/control}="auto", ATTR{power/autosuspend_delay_ms}="100"

    # let the video group pin the dGPU on/off runtime PM (quickshell GPU pill right-click)
    ACTION=="add|bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", RUN+="${pkgs.coreutils}/bin/chgrp video /sys%p/power/control", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys%p/power/control"

    # stable paths for AQ_DRM_DEVICES in hypr/env.lua (cardN numbering changes between boots)
    KERNEL=="card*", KERNELS=="0000:04:00.0", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/amd-igpu"
    KERNEL=="card*", KERNELS=="0000:01:00.0", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/nvidia-dgpu"
  '';

  environment.sessionVariables = {
    # Force the EGL loader to use Mesa (iGPU) for the desktop compositor
    #__EGL_VENDOR_LIBRARY_FILENAMES = "/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json";
    __GLX_VENDOR_LIBRARY_NAME = "mesa"; # Default to Mesa for GL apps
  };

  hardware.nvidia = {

    # Modesetting is required.

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    powerManagement.enable = true;
    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    powerManagement.finegrained = true;

    # Use the NVidia open source kernel module (not to be confused with the
    # independent third-party "nouveau" open source driver).
    # Support is limited to the Turing and later architectures. Full list of
    # supported GPUs is at:
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
    # Only available from driver 515.43.04+
    # Currently alpha-quality/buggy, so false is currently the recommended setting.
    open = false;

    # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
    nvidiaSettings = true;
    nvidiaPersistenced = true;
    modesetting.enable = true;
    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    #package = config.boot.kernelPackages.nvidiaPackages.stable; # old stable package
    package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
      version = "610.57.04";
      sha256_64bit = "sha256-suk1xmuDuwDAyFe8jg7g/VLekoa0DJzB7sKafOfrEW0=";
      openSha256 = "sha256-rQHOOOY4KL92Ww3KDwh+j4eGU7oNAH8LutZC5wmFnPo=";
      settingsSha256 = "sha256-ZEMo8I8Zc2Tq6RVDNYpAH+f094dUaZiBqO+5f6lIjRI=";
      persistencedSha256 = "sha256-aXmD2VY1RLlgAnlHhOUMWzvMyhI6JTClcFLm4imF/mA=";
    };

    prime = {
      offload.enable = true;
      amdgpuBusId = "PCI:4:0:0";
      nvidiaBusId = "PCI:1:0:0";
    };

  };

}
