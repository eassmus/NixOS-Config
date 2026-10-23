local dir = os.getenv("HOME") .. "/.config/hypr/shaders/"
local default = dir .. "black-corners.glsl"
local night = dir .. "black-corners-blue-light-filter.glsl"

-- Hyprland only forces 2 full redraws after a shader change, but the swapchain
-- has 3 buffers, so one keeps old-shader pixels and frames flicker between them
-- until everything gets redrawn. Setting it again a moment later forces 2 more.
local function apply(path) hl.config({ decoration = { screen_shader = path } }) end
local function set(path)
  apply(path)
  hl.timer(function() apply(path) end, { timeout = 100, type = "oneshot" })
end

-- blue light filter from midnight to 6am
set(os.date("*t").hour < 6 and night or default)

hl.bind("SUPER + SHIFT + F11", function()
  set(hl.get_config("decoration.screen_shader") == night and default or night)
end, { transparent = true })
