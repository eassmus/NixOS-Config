#!/bin/bash

if [ -z "$1" ]; then
    echo "Error: Please provide a wallpaper file as an argument."
    exit 1
fi
if [ ! -f "$1" ]; then
    echo "Error: File not found: $1"
    exit 1
fi

hyprpaper_config_file="$HOME/.config/hypr/hyprpaper.conf"

# Persist the new wallpaper so it survives a hyprpaper restart / re-login.
sed -i "s|^\(\s*path = \).*$|\1$1|" "$hyprpaper_config_file"

# Live, seamless swap via hyprctl — no killall, no blink.
hyprctl hyprpaper wallpaper ",$1" >/dev/null

echo "Wallpaper changed."
