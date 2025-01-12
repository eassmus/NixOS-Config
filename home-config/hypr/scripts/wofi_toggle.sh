pkill wofi
if [ $? -eq 1 ]; then
  wofi --show drun
fi
