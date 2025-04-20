pkill hyprpaper

WP_PATH="/home/pulsar/Wallpapers/Active/"
cd $WP_PATH
LAST=$(cat /home/pulsar/.config/hypr/scripts/last_wallpaper)

NEW=$LAST

FOUND="0"

for FILE in $WP_PATH*; do
  if [ "$FOUND" == "1" ]; then 
    NEW=$FILE
    break 
  fi
  if [ "$FILE" == "$LAST" ]; then
    FOUND="1"
  fi
done

echo $NEW > "/home/pulsar/.config/hypr/scripts/last_wallpaper"

/home/pulsar/.config/hypr/scripts/change_wallpaper.sh $NEW
