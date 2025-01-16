# Function to parse CPU usage from /proc/stat
get_cpu_stats() {
    # Read the first line of /proc/stat (total CPU usage line)
    awk '/^cpu / {print $2, $3, $4, $5, $6, $7, $8}' /proc/stat
}

# Get initial CPU stats
cpu1=($(get_cpu_stats))
idle1=${cpu1[3]}
total1=0

for value in "${cpu1[@]}"; do
    total1=$((total1 + value))
done

# Short sleep to measure CPU usage
sleep 0.1

# Get second CPU stats
cpu2=($(get_cpu_stats))
idle2=${cpu2[3]}
total2=0

for value in "${cpu2[@]}"; do
    total2=$((total2 + value))
done

# Calculate deltas
idle_diff=$((idle2 - idle1))
total_diff=$((total2 - total1))

# Avoid division by zero and calculate CPU usage
if [ $total_diff -gt 0 ]; then
    cpu_usage=$(awk "BEGIN {printf \"%.0f\", (1 - $idle_diff / $total_diff) * 100}")
else
    cpu_usage="0.00"
fi

# Output CPU usage
echo "${cpu_usage}"
