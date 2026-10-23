local float = {
  { title = "^(Media viewer)$" },
  { title = "^(Sign In - Google Accounts — Mozilla Firefox)$" },
  { title = "^(Python Turtle Graphics)$" },
  { class = "^(steam)$", title = "^(Friends List)$" },
  { title = "^(Bluetooth Devices)$" },
  { class = "^(firefox)$", title = "^(Library)$" },
}

-- Picture in picture windows
local float_pinned = {
  { title = "^(Picture-in-Picture)$" },
  { class = "^(vesktop)$", title = "^(Discord Popout)$" },
}

for _, match in ipairs(float) do
  hl.window_rule({ match = match, float = true })
end

for _, match in ipairs(float_pinned) do
  hl.window_rule({ match = match, float = true, pin = true })
end

hl.window_rule({ match = { class = "^(feh)$" }, float = true, center = true })

-- Workspace assign
-- hl.window_rule({ match = { class = "^(discord)$" }, workspace = "3" })
-- hl.window_rule({ match = { class = "^(spotify)$" }, workspace = "3" })

hl.layer_rule({ match = { namespace = "hyprpicker" }, no_anim = true })
hl.layer_rule({ match = { namespace = "selection" }, no_anim = true })
