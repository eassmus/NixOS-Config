A= cat /sys/class/graphics/fb0/device/gpu_busy_percent 2>/dev/null
if [ $? -eq 1 ]; then
  A= cat /sys/class/graphics/fb1/device/gpu_busy_percent
fi
echo $A
