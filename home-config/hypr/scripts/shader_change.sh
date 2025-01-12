R=$(hyprshade current)
if [ "$R" = "black-corners-blue-light-filter" ]; then
  hyprshade on black-corners 
else 
  hyprshade on black-corners-blue-light-filter
fi
