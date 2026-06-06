#!/bin/bash

# 1. Disable external monitors
# This is crucial because if a monitor is plugged in, the dGPU CANNOT sleep.
# Get a list of all monitors and disable anything that isn't the eDP (Internal)
monitors=$(hyprctl monitors -j | jq -r '.[].name')
for mon in $monitors; do
    if [[ "$mon" != "eDP-1" ]]; then
        hyprctl keyword monitor "$mon,disable"
    fi
done

# 2. Kill processes using the dGPU
# We find PIDs using /dev/nvidia* and kill them.
# We exclude 'nvidia-persistenced' (PID of the daemon) to avoid system instability.
PIDS=$(fuser -v /dev/nvidia* 2>/dev/null | awk '{print $2}' | grep -v "PID" | sort -u)

for PID in $PIDS; do
    # Check if it's the persistence daemon before killing
    PNAME=$(ps -p "$PID" -o comm=)
    if [[ "$PNAME" != "nvidia-persiste" ]]; then
        kill -9 "$PID"
    fi
done

# 3. Clear the Waybar "Pending Suspend" window
# This forces the bar to show 'XX' as soon as the kernel suspends the card.
rm -f /tmp/nvidia_suspend_ts
