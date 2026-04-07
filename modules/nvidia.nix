{
  pkgs,
  config,
  libs,
  ...
}:

let
  nvidia-offload = pkgs.writeShellScriptBin "nvidia-offload" ''
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __VK_LAYER_NV_optimus=NVIDIA_only
    export AQ_DRM_DEVICES="/dev/dri/card1:/dev/dri/card0"
    export WLR_DRM_DEVICES="/dev/dri/card1:/dev/dri/card0"
    export __EGL_VENDOR_LIBRARY_FILENAMES="/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json"
    exec -a "$0" "$@"
  '';
in
{
  # Enable OpenGL
  hardware.graphics.enable = true;

  # Load nvidia driver for Xorg and Wayland
  environment.systemPackages = [ nvidia-offload ];
  services.xserver.videoDrivers = [ "nvidia" ];

  boot.kernelParams = [ 
    "nvidia.NVreg_DynamicPowerManagement=0x02"
    "nvidia.NVreg_DynamicPowerManagementVideoMemoryThreshold=0"
    "nvidia_drm.fbdev=0" 
  ];

  services.udev.extraRules = ''
    # Use add|bind to ensure the rule hits regardless of module load timing
    ACTION=="add|bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}="0x030000", ATTR{power/control}="auto", ATTR{power/autosuspend_delay_ms}="100"
    ACTION=="add|bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}="0x030200", ATTR{power/control}="auto", ATTR{power/autosuspend_delay_ms}="100"
  '';

  environment.sessionVariables = {
    # Force iGPU (card1) as primary, dGPU (card0) as secondary
    AQ_DRM_DEVICES = "/dev/dri/card1:/dev/dri/card0";
    WLR_DRM_DEVICES = "/dev/dri/card1:/dev/dri/card0";
    
    # Force the EGL loader to use Mesa (iGPU) for the desktop compositor
    __EGL_VENDOR_LIBRARY_FILENAMES = "/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json";
    
    # Prevent applications from choosing NVIDIA by default
    __NV_PRIME_RENDER_OFFLOAD = "0";
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
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    prime = {
      offload.enable = true;
      amdgpuBusId = "PCI:4:0:0";
      nvidiaBusId = "PCI:1:0:0";
    };

  };

}
