local mainMod = "SUPER"
local terminal = "kitty"
local scripts = "~/.config/hypr/scripts/"

local function exec(cmd) return hl.dsp.exec_cmd(cmd) end
local bind = hl.bind

local repeating = { repeating = true }
local transparent = { transparent = true }
local repeating_transparent = { repeating = true, transparent = true }
local locked_repeating_transparent = { locked = true, repeating = true, transparent = true }

bind(mainMod .. " + SHIFT + F7", exec("bash " .. scripts .. "brightness_change.sh -5"), locked_repeating_transparent)
bind(mainMod .. " + SHIFT + F8", exec("bash " .. scripts .. "brightness_change.sh 5"), locked_repeating_transparent)
bind(mainMod .. " + SHIFT + F2", exec("brightnessctl -d asus::kbd_backlight s 10%-"), locked_repeating_transparent)
bind(mainMod .. " + SHIFT + F3", exec("brightnessctl -d asus::kbd_backlight s 10%+"), locked_repeating_transparent)
bind("XF86AudioRaiseVolume", exec("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+ & wpctl set-mute @DEFAULT_AUDIO_SINK@ 0"), repeating_transparent)
bind("XF86AudioLowerVolume", exec("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%-"), repeating_transparent)
bind("SHIFT + XF86AudioRaiseVolume", exec("wpctl set-volume -l 1.0 60 5%+ & wpctl set-mute 60 0"), repeating)
bind("SHIFT + XF86AudioLowerVolume", exec("wpctl set-volume -l 1.0 60 5%-"), repeating)

bind("SHIFT + XF86AudioMicMute", exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), transparent)
bind(mainMod .. " + SHIFT + F1", exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), transparent)
bind("XF86AudioMicMute", exec("wpctl set-mute 60 toggle"), transparent)
bind("XF86AudioMute", exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), transparent)
bind("SHIFT + XF86AudioMute", exec("wpctl set-mute 60 toggle"), transparent)

bind("ALT + TAB", hl.dsp.window.cycle_next())
bind(mainMod .. " + D", exec(terminal))
bind(mainMod .. " + S", hl.dsp.window.close(), repeating)
bind(mainMod .. " + SHIFT + S", hl.dsp.window.signal({ signal = 15 }), repeating)
bind(mainMod .. " + CTRL + S", exec(scripts .. "kill_all_windows.sh"), repeating)
bind(mainMod .. " + E", exec("thunar"))
bind(mainMod .. " + B", exec("bash " .. scripts .. "waybar_toggle.sh"), transparent)
bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
bind(mainMod .. " + W", exec("bash " .. scripts .. "wofi_toggle.sh"))
bind(mainMod .. " + P", hl.dsp.window.pseudo()) -- dwindle
bind(mainMod .. " + O", hl.dsp.layout("togglesplit")) -- dwindle

bind(mainMod .. " + Q", exec("wlogout"), repeating)
bind(mainMod .. " + SHIFT + Q", exec("hyprlock"), repeating)

bind(mainMod .. " + Y", exec("hyprshot -m region -o ~/Screenshots/"), repeating)
bind(mainMod .. " + SHIFT + Y", exec("hyprshot -m output -o ~/Screenshots/"), repeating)
bind(mainMod .. " + CTRL + SHIFT + Y", exec("hyprshot -m output -o ~/Screenshots/ --clipboard-only"), repeating)
bind(mainMod .. " + ALT + Y", exec("hyprpicker -a -f hex"), repeating)

bind(mainMod .. " + T", exec(terminal .. " ~/.local/share/Trash"))

bind("code:156", exec(terminal .. " -e btop & " .. terminal .. " -e nvtop"))
bind("Pause", exec(terminal .. " -e btop & " .. terminal .. " -e nvtop"))

-- bind("Home", exec(scripts .. "random_wallpaper.sh"))
-- bind(mainMod .. " + Prior", exec(scripts .. "next_wallpaper.sh"))
-- bind(mainMod .. " + Next", exec(scripts .. "prev_wallpaper.sh"))

bind(mainMod .. " + F", exec("asusctl profile --next"))
bind(mainMod .. " + SHIFT + F", exec("asusctl profile --next && asusctl profile --next"))

local directions = { h = "left", j = "down", k = "up", l = "right" }
local nudge = { h = { -15, 0 }, j = { 0, 15 }, k = { 0, -15 }, l = { 15, 0 } }

for key, dir in pairs(directions) do
  local x, y = nudge[key][1], nudge[key][2]
  bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = dir }))
  bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = dir }))
  bind(mainMod .. " + CTRL + " .. key, hl.dsp.window.resize({ x = x, y = y, relative = true }), repeating)
  bind(mainMod .. " + ALT + " .. key, hl.dsp.window.move({ x = x, y = y, relative = true }), repeating)
end

-- code:59 = comma, code:60 = period
for code, offset in pairs({ [59] = "-", [60] = "+" }) do
  bind(mainMod .. " + code:" .. code, hl.dsp.focus({ workspace = "r" .. offset .. "1" }))
  bind(mainMod .. " + CTRL + code:" .. code, hl.dsp.focus({ workspace = "r" .. offset .. "2" }))
  bind(mainMod .. " + SHIFT + code:" .. code, hl.dsp.window.move({ workspace = "r" .. offset .. "1" }))
  bind(mainMod .. " + SHIFT + CTRL + code:" .. code, hl.dsp.window.move({ workspace = "r" .. offset .. "2" }))
end

for i = 1, 10 do
  local key = tostring(i % 10)
  bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = tostring(i) }))
  bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = tostring(i) }))
end

bind(mainMod .. " + F1", exec("firefox"))
bind(mainMod .. " + F2", exec("discord"))
-- bind(mainMod .. " + F3", exec("kitty -e ncspot 2> /dev/null & kitty -e cava"))
bind(mainMod .. " + F3", exec("spotify"))
bind(mainMod .. " + F5", exec("bash " .. scripts .. "slack_start.sh"))
bind(mainMod .. " + F6", exec(terminal .. " -e ~/.cargo/bin/chatgpt-tui /home/pulsar/.gpttuiconf"))
bind(mainMod .. " + F7", exec("pavucontrol"))
bind(mainMod .. " + F8", exec(terminal .. " -e bc -qil"))
bind(mainMod .. " + F9", exec(terminal .. " -e nmtui"))
bind(mainMod .. " + SHIFT + F12", exec("nmcli device down wlp2s0"), transparent)

bind(mainMod .. " + C", exec(terminal .. " -e cava"))
bind(mainMod .. " + SHIFT + B", exec(terminal .. " -e cbonsai -l -i -t 0.1 -w 0.01 -l 12"), repeating)

bind(mainMod .. " + SHIFT + F9", function()
  hl.monitor({ output = "DP-1", mode = "preferred", position = "auto", scale = 1.0, mirror = "eDP-1" })
end)

bind(mainMod .. " + code:21", exec("playerctl play-pause"))
bind(mainMod .. " + code:34", exec("playerctl previous"))
bind(mainMod .. " + code:35", exec("playerctl next"))

bind(mainMod .. " + code:65", exec("wl-kbptr"))

-- code:20 = minus: jump to a window asking for attention (green workspace dot),
-- or back to the last window when none is
bind(mainMod .. " + code:20", hl.dsp.focus({ urgent_or_last = true }))

bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
bind(mainMod .. " + mouse:274", hl.dsp.window.close())

bind("SUPER + code:47", exec("kitty sudo openconnect umvpn.umnet.umich.edu/umvpn-split-tunnel-alt --useragent=AnyConnect --background"))
bind("SUPER + code:48", exec("kitty sudo pkill openconnect"))

local function zoom(delta)
  return function()
    local z = hl.get_config("cursor.zoom_factor") + delta
    hl.config({ cursor = { zoom_factor = math.max(z, 1) } })
  end
end

bind(mainMod .. " + i", zoom(0.5), repeating) -- Zoom in
bind(mainMod .. " + u", zoom(-0.5), repeating) -- Zoom out
bind(mainMod .. " + SHIFT + u", function() hl.config({ cursor = { zoom_factor = 1 } }) end) -- Reset zoom

bind(mainMod .. " + g", exec("bash " .. scripts .. "gpu_up.sh"))
bind(mainMod .. " + ALT + F", exec("bash " .. scripts .. "gpu_amd_only_toggle.sh"))

bind(mainMod .. " + z", exec("wlrctl pointer click left"))
bind(mainMod .. " + x", exec("wlrctl pointer click right"))
