hl.on("hyprland.start", function()
  -- login screen: log out if hyprlock fails instead of leaving the session unlocked
  hl.exec_cmd("hyprlock --no-fade-in --immediate-render || hyprctl dispatch 'hl.dsp.exit()'")

  hl.exec_cmd("dbus-update-activation-environment --systemd --all")
  hl.exec_cmd("dbus-update-activation-environment --systemd HYPRLAND_INSTANCE_SIGNATURE")
  -- polkit agent (user service in modules/polkit.nix): its graphical-session.target
  -- trigger never fires without uwsm, so start it here once it has WAYLAND_DISPLAY
  hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
    .. " && systemctl --user start polkit-gnome-authentication-agent-1")

  hl.exec_cmd("hyprpaper")
  hl.exec_cmd("bash ~/.config/hypr/scripts/waybar_toggle.sh")
  hl.exec_cmd("fcitx5 -d -r")
  hl.exec_cmd("fcitx5-remote -r")
  hl.exec_cmd("hypridle")
  hl.exec_cmd("nwg-look -a")
  hl.exec_cmd("hyprctl setcursor McMojave 36")
  -- hl.exec_cmd("asusctl profile --profile-set Quiet")

  hl.exec_cmd("sleep 1 && wpctl set-mute @DEFAULT_AUDIO_SINK@ 1")
  hl.exec_cmd("sleep 1 && wpctl set-mute 60 1")

  -- hl.exec_cmd("sleep 3 && asusctl profile --next && asusctl profile --next")

  -- hl.exec_cmd("kitty -e btop", { workspace = "10", no_initial_focus = true })
  -- hl.exec_cmd("kitty -e nvtop", { workspace = "10", no_initial_focus = true })

  -- hl.exec_cmd("discord", { workspace = "3 silent" })
end)
