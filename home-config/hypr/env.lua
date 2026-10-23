hl.env("QT_QPA_PLATFORM", "wayland;xcb")
-- iGPU renders, dGPU only drives its DP port; symlinks come from udev rules in modules/nvidia.nix
hl.env("AQ_DRM_DEVICES", "/dev/dri/amd-igpu:/dev/dri/nvidia-dgpu")
hl.env("WLR_RENDERER_ALLOW_SOFTWARE", "1")

-- "AMD only" (default; GPU popup / SUPER+ALT+F via scripts/gpu_amd_only_toggle.sh):
-- hides the dGPU from Vulkan so apps like Discord can't wake it.
-- CUDA/nvidia-smi don't use this, and `nvidia-offload <app>` undoes it per app.
local flag = io.open(os.getenv("XDG_RUNTIME_DIR") .. "/gpu-allow-nvidia")
local amdOnly = flag == nil
if flag then flag:close() end

-- EGL must keep both vendors: hl.env also applies to Hyprland itself, which needs
-- NVIDIA's EGL to copy frames to the DP-1 output. Listed explicitly (not left unset)
-- so a reload overrides older values; an empty value would leave apps with no drivers.
local glvnd = "/run/opengl-driver/share/glvnd/egl_vendor.d/"
hl.env("__EGL_VENDOR_LIBRARY_FILENAMES", glvnd .. "10_nvidia.json:" .. glvnd .. "50_mesa.json")

local icd = "/run/opengl-driver/share/vulkan/icd.d/"
hl.env("VK_DRIVER_FILES", amdOnly and icd .. "radeon_icd.x86_64.json"
  or icd .. "nvidia_icd.json:" .. icd .. "radeon_icd.x86_64.json")
