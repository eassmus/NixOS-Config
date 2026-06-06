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
sed -i -e "s|^preload = .*$|preload = $1|" \
       -e "s|^wallpaper = .*$|wallpaper = ,$1|" \
       "$hyprpaper_config_file"

# Live, seamless swap via hyprctl — no killall, no blink.
hyprctl hyprpaper preload   "$1"   >/dev/null
hyprctl hyprpaper wallpaper ",$1"  >/dev/null
hyprctl hyprpaper unload    unused >/dev/null

echo "Wallpaper changed."
