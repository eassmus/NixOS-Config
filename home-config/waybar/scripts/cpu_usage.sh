# Aggregate /proc/stat sample matching CpuPopup.qml:
#   - 1 second window
#   - "idle" = idle + iowait (fields 4 and 5)

get_cpu_stats() {
    awk '/^cpu / {print $2, $3, $4, $5, $6, $7, $8}' /proc/stat
}

cpu1=($(get_cpu_stats))
idle1=$((${cpu1[3]} + ${cpu1[4]}))
total1=0
for value in "${cpu1[@]}"; do
    total1=$((total1 + value))
done

sleep 1

cpu2=($(get_cpu_stats))
idle2=$((${cpu2[3]} + ${cpu2[4]}))
total2=0
for value in "${cpu2[@]}"; do
    total2=$((total2 + value))
done

idle_diff=$((idle2 - idle1))
total_diff=$((total2 - total1))

if [ $total_diff -gt 0 ]; then
    cpu_usage=$(awk "BEGIN {printf \"%2.0f\", (1 - $idle_diff / $total_diff) * 100}")
else
    cpu_usage="0"
fi

echo "${cpu_usage}"
