#!/bin/bash

PCI_ID="0000:01:00.0"
STATUS_FILE="/sys/bus/pci/devices/$PCI_ID/power/runtime_status"
TMP_TS="/tmp/nvidia_suspend_ts"
ACTIVE_TS="/tmp/nvidia_active_ts"
THRESHOLD=5 # MiB; idle dGPU sits at ~2
GRACE=5     # s awake before we query, so brief wake-ups (boot, a probe) fall back asleep

# 1. THE PASSIVE GATE
# We check the kernel first. If it's already asleep, DO NOT touch nvidia-smi.
read -r STATUS < "$STATUS_FILE"
if [[ "$STATUS" == "suspended" ]]; then
    # test first: [[ ]] is a builtin, rm is a process spawn every poll
    [[ -e "$TMP_TS" || -e "$ACTIVE_TS" ]] && rm -f "$TMP_TS" "$ACTIVE_TS"
    echo "󰢮 󰒲 %"
    echo "off"
    exit 0
fi

# 1b. THE GRACE GATE
# Every nvidia-smi call restarts the driver's idle timer, so leave a freshly
# woken card alone for a few seconds.
[ -f "$ACTIVE_TS" ] || date +%s > "$ACTIVE_TS"
if (( $(date +%s) - $(<"$ACTIVE_TS") < GRACE )); then
    echo "󰢮  0%"
    exit 0
fi

# 2. THE QUIET WINDOW GATE
# If we saw low VRAM recently, we stay in "PS" mode and don't touch the card.
if [ -f "$TMP_TS" ]; then
    TS=$(cat "$TMP_TS")
    NOW=$(date +%s)
    if (( NOW - TS < 60 )); then
        echo "󰢮  0%"
        exit 0
    else
        rm "$TMP_TS" 
    fi
fi

# 3. THE NVIDIA-SMI CHECK
# If we reached here, the card is 'active' and we aren't in a cool-down.
# We query memory, utilization and temperature in one shot to be efficient.
QUERY=$(nvidia-smi --query-gpu=memory.used,utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null)
VRAM_USED=$(echo "$QUERY" | cut -d',' -f1 | tr -d ' ')
UTIL=$(echo "$QUERY" | cut -d',' -f2 | tr -d ' ')
TEMP=$(echo "$QUERY" | cut -d',' -f3 | tr -d ' ')

# 4. THRESHOLD LOGIC
if [ "$VRAM_USED" -le "$THRESHOLD" ]; then
    # VRAM is low (e.g., that 2MB ghost usage). 
    # Set the 15s timestamp to stop pings and allow autosuspend.
    date +%s > "$TMP_TS"
    echo "󰢮  0%"
else
    # Actual usage detected.
    #echo "󰢮 ${UTIL}%"
    printf "󰢮 %2d%%\n" "$UTIL"
fi
# line 2: temp for the thermal graph ("off" = asleep; absent = not queried this poll)
echo "$TEMP"
