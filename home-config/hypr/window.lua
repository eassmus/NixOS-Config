hl.config({
  general = {
    gaps_in = 10,
    gaps_out = 20,
    border_size = 6,
    col = {
      active_border = { colors = { "rgba(82aee8ff)", "rgba(e9a6fdff)" }, angle = 90 },
      inactive_border = { colors = { "rgba(21182780)" }, angle = 45 },
    },
    layout = "dwindle",
    allow_tearing = false,
  },

  decoration = {
    rounding = 10,
    blur = {
      enabled = true,
      size = 4,
      passes = 6,
      new_optimizations = true,
      xray = false,
    },
    shadow = {
      enabled = false,
    },
  },

  animations = {
    enabled = true,
  },

  dwindle = {
    preserve_split = true,
  },

  -- master = {
  --   new_is_master = true,
  -- },

  misc = {
    force_default_wallpaper = 0,
  },
})

hl.curve("overshot", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.curve("smoothOut", { type = "bezier", points = { { 0.36, 0 }, { 0.66, -0.56 } } })
hl.curve("smoothIn", { type = "bezier", points = { { 0.25, 1 }, { 0.5, 1 } } })
hl.curve("smooth", { type = "bezier", points = { { 0.6, 0 }, { 0.6, 1 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "default", style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "smoothOut", style = "slide" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 12, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 10, bezier = "smoothIn" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 10, bezier = "smoothIn" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default" })
