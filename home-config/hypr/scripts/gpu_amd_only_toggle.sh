#!/bin/bash
# Toggle "AMD only" (on by default): while on, apps launched from Hyprland can't see
# the dGPU. env.lua reads this flag, so a reload applies it. Running apps are unaffected.
f="$XDG_RUNTIME_DIR/gpu-allow-nvidia"
if [ -e "$f" ]; then rm "$f"; else touch "$f"; fi
hyprctl reload >/dev/null
