#!/bin/bash

# 1. Wake the card immediately
# This pulls the card out of D3cold
nvidia-smi > /dev/null 2>&1

# 2. Reload Hyprland configuration
# This resets any 'monitor disable' keywords you ran in the evacuate script
# and reverts to whatever is defined in your hyprland.conf
hyprctl reload

# 3. Optional: Specific monitor re-enable
# If 'reload' isn't enough for your specific setup, you can force auto-detection:
# hyprctl keyword monitor ",preferred,auto,1"
